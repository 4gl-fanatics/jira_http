/** This is free and unencumbered software released into the public domain.

    Anyone is free to copy, modify, publish, use, compile, sell, or
    distribute this software, either in source code form or as a compiled
    binary, for any purpose, commercial or non-commercial, and by any
    means.  **/
/*------------------------------------------------------------------------
    File        : get_release_notes.p
    Purpose     :

    Syntax      :

    Description :

    Author(s)   : Peter Judge / Consultingwerk Ltd
    Created     : Mon Aug 29 06:30:55 EDT 2022
    Notes       :
  ----------------------------------------------------------------------*/

/* ***************************  Definitions  ************************** */

BLOCK-LEVEL ON ERROR UNDO, THROW.

USING OpenEdge.Core.*.
USING OpenEdge.Net.*.
USING OpenEdge.Net.HTTP.*.
USING OpenEdge.Net.HTTP.Lib.*.
USING Progress.Json.ObjectModel.*.

/* ***************************  Main Block  *************************** */
{common_functions.i}

DEFINE TEMP-TABLE ttRelNote NO-UNDO     SERIALIZE-NAME "releaseNotes"
    FIELD JiraId AS CHARACTER
    FIELD IssueType AS CHARACTER
    FIELD IssueDescription AS CLOB
    FIELD NoteTitle AS CHARACTER
    FIELD NoteDescription AS CLOB
    INDEX id1 AS PRIMARY UNIQUE JiraId
    .

DEFINE TEMP-TABLE ttAttachment NO-UNDO  SERIALIZE-NAME "attachments"
    FIELD JiraId AS CHARACTER
    FIELD Attachment AS blob
    FIELD ContentType AS CHARACTER
    FIELD Filename AS CHARACTER
    FIELD AttachmentUrl AS CHARACTER
    INDEX idx1 JiraId
    .

DEFINE DATASET dsRelnote FOR ttRelNote, ttAttachment
    DATA-RELATION FOR ttRelNote, ttAttachment RELATION-FIELDS (JiraId, JiraId) NESTED
    .

DEFINE VARIABLE hc AS IHttpClient NO-UNDO.
DEFINE VARIABLE creds AS Credentials NO-UNDO.
DEFINE VARIABLE body AS JsonConstruct NO-UNDO.
DEFINE VARIABLE restUrl AS URI NO-UNDO.
DEFINE VARIABLE versionId AS CHARACTER NO-UNDO.

SESSION:ERROR-STACK-TRACE = YES.
SESSION:DEBUG-ALERT = NO.
LOG-MANAGER:LOGFILE-NAME = 'jira.log'.
LOG-MANAGER:LOGGING-LEVEL = 5.
LOG-MANAGER:CLEAR-LOG().

&SCOPED-DEFINE API-VERSION 2
&SCOPED-DEFINE BASE-URL https://consultingwerk.atlassian.net/rest/api/{&API-VERSION}

// Global-to-procedure value
RUN build_client (FALSE, OUTPUT hc).
RUN get_credentials (OUTPUT creds).

/* From our config file ...
  "JiraRestApiUrl":"https://consultingwerk.atlassian.net/rest/api/2",
  "JiraProject":"SCL",
  "JiraSearchPath":"search",
  "JiraVersionPath":"project/&1/version",
  "JiraReleaseNoteDescriptionField":"customfield_12401",
  "JiraReleaseNoteTitleField":"customfield_12400",
  "JiraIssuesInVersionQuery":"project=&1 AND fixVersion='&2'",
*/

// 1. Get the fixed versions for the SCL project
restUrl = URI:Parse("{&BASE-URL}/project/SCL/version").
restUrl:AddQuery ("orderBy":U,"-releaseDate":U).

RUN get_request(hc, restUrl, creds, OUTPUT body).

body:WriteFile('versions.json', YES).

RUN get_latest_release(cast(body, JsonObject):GetJsonArray("values"), OUTPUT versionId).

// 2. Get all tickets fixed in that version
restUrl = URI:Parse("{&BASE-URL}/search").
restUrl:AddQuery("jql", SUBSTITUTE("project=SCL AND fixVersion='&1' AND (issueType='Bug' OR issueType='Improvement')",
                                    versionId)).

RUN get_request(hc, restUrl, creds, OUTPUT body).

//body:WriteFile('tickets.json', YES).

// 3. Get all the release notes from those tickets
RUN get_release_notes(cast(body, JsonObject):GetJsonArray("issues")).

FOR EACH ttRelNote:
    // 4. Download attachments for the release notes
    RUN get_attachments (INPUT ttRelNote.JiraId).
END.

DATASET dsRelnote:WRITE-JSON ("FILE", "relnotes.json", YES).

// Do something with the release note data
CURRENT-WINDOW:WIDTH-CHARS = 128.
FOR EACH ttRelNote:
   DISPLAY
    ttRelNote.JiraId
    ttRelNote.IssueType FORMAT "x(11)"
    ttRelNote.NoteTitle FORMAT "x(90)"
    WITH
        WIDTH 128
    .
END.

CATCH e AS Progress.Lang.Error :
    MESSAGE
        e:GetMessage(1) SKIP(2)
        e:CallStack
        VIEW-AS ALERT-BOX.
END CATCH.

PROCEDURE get_latest_release:
    DEFINE INPUT  PARAMETER pData AS JsonArray NO-UNDO.
    DEFINE OUTPUT PARAMETER pVersionId AS CHARACTER NO-UNDO.

    DEFINE VARIABLE loop AS INTEGER NO-UNDO.
    DEFINE VARIABLE verJson AS JsonObject NO-UNDO.
    DEFINE VARIABLE verDate AS DATE EXTENT 2 NO-UNDO.

    DO loop = 1 TO pData:LENGTH:
        IF NOT pData:GetType(loop) EQ  JsonDataType:OBJECT THEN
            NEXT.

        verJson = pData:GetJsonObject(loop).
        IF NOT verJson:Has("releaseDate") THEN
            NEXT.

        pVersionId = verJson:GetCharacter("name").
        RETURN.
    END.
END PROCEDURE.

PROCEDURE get_release_notes:
    DEFINE INPUT  PARAMETER pData AS JsonArray NO-UNDO.

    DEFINE VARIABLE loop AS INTEGER NO-UNDO.
    DEFINE VARIABLE cnt AS INTEGER NO-UNDO.
    DEFINE VARIABLE issJson AS JsonObject NO-UNDO.
    DEFINE VARIABLE fieldsJson AS JsonObject NO-UNDO.

    EMPTY TEMP-TABLE ttRelNote.

    cnt = pData:LENGTH.
    DO loop = 1 TO cnt:
        ASSIGN issJson    = pData:GetJsonObject(loop)
               fieldsJson = issJson:GetJsonObject("fields")
                .

        // is there release note data?
        IF NOT fieldsJson:Has("customfield_12400")
        OR fieldsJson:GetType("customfield_12400") EQ JsonDataType:NULL
        OR NOT fieldsJson:Has("customfield_12401")
        OR fieldsJson:GetType("customfield_12401") EQ JsonDataType:NULL
        THEN
            NEXT.

        CREATE ttRelNote.
        ASSIGN ttRelNote.JiraId    = issJson:GetCharacter("key")
               ttRelNote.IssueType = fieldsJson:GetJsonObject("issuetype"):GetCharacter("name").
               ttRelNote.NoteTitle = fieldsJson:GetCharacter("customfield_12400")
               .
        COPY-LOB FROM fieldsJson:GetLongchar("description") TO ttRelNote.IssueDescription NO-ERROR.
        // release note text
        COPY-LOB FROM fieldsJson:GetLongchar("customfield_12401") TO ttRelNote.NoteDescription NO-ERROR.

        IF ttRelNote.NoteTitle EQ "." THEN
            ttRelNote.NoteTitle = fieldsJson:GetCharacter("summary").
    END.
END PROCEDURE.

PROCEDURE get_attachments:
    DEFINE INPUT  PARAMETER pJiraId AS CHARACTER NO-UNDO.

    DEFINE VARIABLE restUrl AS URI NO-UNDO.
    DEFINE VARIABLE attachmentJson AS JsonObject NO-UNDO.
    DEFINE VARIABLE respBody AS JsonConstruct NO-UNDO.
    DEFINE VARIABLE issueJson AS JsonArray NO-UNDO.
    DEFINE VARIABLE attachJson AS JsonArray NO-UNDO.
    DEFINE VARIABLE fieldJson AS JsonObject NO-UNDO.
    DEFINE VARIABLE ticketJson AS JsonObject NO-UNDO.
    DEFINE VARIABLE iLoop AS INTEGER NO-UNDO.
    DEFINE VARIABLE iCnt AS INTEGER NO-UNDO.
    DEFINE VARIABLE aLoop AS INTEGER NO-UNDO.
    DEFINE VARIABLE aCnt AS INTEGER NO-UNDO.
    DEFINE VARIABLE req AS IHttpRequest NO-UNDO.
    DEFINE VARIABLE resp AS IHttpResponse NO-UNDO.

    // to get attachment info
    restUrl = URI:Parse("{&BASE-URL}/search").

    // get any attachments
    restUrl:AddQuery('jql':U, SUBSTITUTE ("Issuekey=&1":U, pJiraId)).
    restUrl:AddQuery("fields":U, "attachment":U).

    RUN get_request(hc, restUrl, creds, OUTPUT respBody).

    respBody:WriteFile("attachments-" + pJiraId + ".json", YES).

    IF TYPE-OF(respBody, JsonObject) THEN
        attachmentJson = CAST(respBody, JsonObject).
    ELSE
        RETURN.

    // To get the actual attachment
    issueJson = attachmentJson:getJsonArray("issues").
    iCnt = issueJson:length.
    DO iLoop = 1 TO iCnt:
        ticketJson = issueJson:GetJsonObject(iLoop).

        IF NOT ticketJson:Has("fields") THEN
            NEXT.

        attachJson = ticketJson:GetJsonObject("fields"):GetJsonArray("attachment").
        aCnt = attachJson:Length.
        DO aLoop = 1 TO aCnt:
            attachmentJson = attachJson:GetJsonObject(aLoop).

            CREATE ttAttachment.
            ASSIGN ttAttachment.JiraId        = pJiraId
                   ttAttachment.ContentType   = attachmentJson:GetCharacter("mimeType")
                   ttAttachment.Filename      = attachmentJson:GetCharacter("filename")
                   ttAttachment.AttachmentUrl = attachmentJson:GetCharacter("content")
                   .
            restUrl = URI:Parse(ttAttachment.AttachmentUrl).

            // Download the individyual attachments
            req = RequestBuilder:Get(restUrl)
                        :UsingBasicAuthentication (creds)
                        :Request.
            resp = hc:Execute(req).

            IF TYPE-OF(resp:Entity, ByteBucket) THEN
                COPY-LOB FROM CAST(resp:Entity, ByteBucket):Value TO ttAttachment.Attachment.
        END.
    END.
END PROCEDURE.