/** This is free and unencumbered software released into the public domain.

    Anyone is free to copy, modify, publish, use, compile, sell, or
    distribute this software, either in source code form or as a compiled
    binary, for any purpose, commercial or non-commercial, and by any
    means.  **/
/*------------------------------------------------------------------------
    File        : update_ticket.p
    Purpose     :

    Syntax      :

    Description :

    Author(s)   : Peter Judge / Consultingwerk Ltd
    Created     : Fri Dec 09 10:12:08 EST 2022
    Notes       : https://docs.atlassian.com/jira/REST/server/
  ----------------------------------------------------------------------*/

/* ***************************  Definitions  ************************** */

BLOCK-LEVEL ON ERROR UNDO, THROW.

USING OpenEdge.Core.String FROM PROPATH.
USING OpenEdge.Core.StringConstant FROM PROPATH.
USING OpenEdge.Net.HTTP.Credentials FROM PROPATH.
USING OpenEdge.Net.HTTP.HttpHeaderBuilder FROM PROPATH.
USING OpenEdge.Net.HTTP.IHttpClient FROM PROPATH.
USING OpenEdge.Net.MessagePart FROM PROPATH.
USING OpenEdge.Net.MultipartEntity FROM PROPATH.
USING OpenEdge.Net.URI FROM PROPATH.
USING Progress.IO.FileInputStream FROM PROPATH.
USING Progress.Json.ObjectModel.JsonArray FROM PROPATH.
USING Progress.Json.ObjectModel.JsonConstruct FROM PROPATH.
USING Progress.Json.ObjectModel.JsonObject FROM PROPATH.
USING Progress.Json.ObjectModel.ObjectModelParser FROM PROPATH.

SESSION:ERROR-STACK-TRACE = YES.
SESSION:DEBUG-ALERT = NO.
LOG-MANAGER:LOGFILE-NAME = 'jira.log'.
LOG-MANAGER:LOGGING-LEVEL = 5.
LOG-MANAGER:CLEAR-LOG().

/* ***************************  Main Block  *************************** */
&SCOPED-DEFINE API-VERSION latest
&SCOPED-DEFINE BASE-URL https://consultingwerk.atlassian.net/rest/api

{common_functions.i}

DEFINE TEMP-TABLE ttAssignableUser NO-UNDO
    FIELD DisplayName  AS CHARACTER
    FIELD AccountId    AS CHARACTER
    FIELD EmailAddress AS CHARACTER
    INDEX idx1 AS PRIMARY UNIQUE AccountId
    INDEX idx2                   DisplayName
    .

DEFINE VARIABLE hc       AS IHttpClient NO-UNDO.
DEFINE VARIABLE creds    AS Credentials NO-UNDO.
DEFINE VARIABLE issueId  AS CHARACTER   NO-UNDO.
DEFINE VARIABLE issueKey AS CHARACTER   NO-UNDO.

// Global-to-procedure values
RUN build_client (TRUE, OUTPUT hc).
RUN get_credentials (OUTPUT creds).



/* ***************************  Internal Procedures  *************************** */
PROCEDURE get_issue_id:
    DEFINE INPUT  PARAMETER pIssueKey AS CHARACTER NO-UNDO.
    DEFINE OUTPUT PARAMETER pIssueId  AS CHARACTER NO-UNDO.

    DEFINE VARIABLE body AS JsonConstruct NO-UNDO.

    RUN get_request(hc,
                    URI:Parse("{&BASE-URL}/{&API-VERSION}/issue/" + pIssueKey),
                    creds,
                    OUTPUT body).

    IF cast(body, JsonObject):Has("id") THEN
        pIssueId = cast(body, JsonObject):GetCharacter("id").
    ELSE
        pIssueId = ?.
END PROCEDURE.

/* -- Add a new comment -- */
PROCEDURE add_comment_addcomment:
    DEFINE INPUT  PARAMETER pIssueId AS CHARACTER NO-UNDO.
    DEFINE INPUT  PARAMETER pComment AS CHARACTER NO-UNDO.

    DEFINE VARIABLE commentBody AS JsonObject NO-UNDO.
    DEFINE VARIABLE jo          AS JsonObject NO-UNDO.
    DEFINE VARIABLE restUrl     AS URI        NO-UNDO.

    commentBody = NEW JsonObject().
    jo = CAST(NEW ObjectModelParser():Parse(pComment), JsonObject) NO-ERROR.
    IF VALID-OBJECT(jo) THEN
    DO:
        commentBody:Add("body", jo).
        /* ADF must be v3 */
        restUrl = URI:Parse("{&BASE-URL}/3/issue/" + pIssueId + "/comment").
    END.
    ELSE
    DO:
        commentBody:Add("body", pComment).
        restUrl = URI:Parse("{&BASE-URL}/{&API-VERSION}/issue/" + pIssueId + "/comment").
    END.

    restUrl:AddQuery("expand", "renderedBody").

    RUN post_new_request(hc, restUrl, creds, commentBody, OUTPUT commentBody).

    //commentBody:writefile('add-comment.json', yes).
END PROCEDURE.

PROCEDURE add_comment_editissue:
    DEFINE INPUT  PARAMETER pIssueId AS CHARACTER NO-UNDO.
    DEFINE INPUT  PARAMETER pComment AS CHARACTER NO-UNDO.

    DEFINE VARIABLE commentBody AS JsonObject NO-UNDO.
    DEFINE VARIABLE jo          AS JsonObject NO-UNDO.
    DEFINE VARIABLE jo2         AS JsonObject NO-UNDO.
    DEFINE VARIABLE jo3         AS JsonObject NO-UNDO.
    DEFINE VARIABLE ja          AS JsonArray  NO-UNDO.
    DEFINE VARIABLE restUrl     AS URI        NO-UNDO.

    commentBody = NEW JsonObject().
    jo = NEW JsonObject().
    commentBody:Add("update", jo).
    ja = NEW JsonArray().
    jo:Add("comment", ja).

    jo = NEW JsonObject().
    ja:Add(jo).

    jo2 = NEW JsonObject().
    jo:Add("add", jo2).

    jo3 = cast(NEW ObjectModelParser():Parse(pComment), JsonObject) NO-ERROR.
    IF VALID-OBJECT(jo3) THEN
    DO:
        jo2:Add("body", jo3).
        /* ADF must be v3 */
        restUrl = URI:Parse("{&BASE-URL}/3/issue/" + pIssueId).
    END.
    ELSE
    DO:
        jo2:Add("body", pComment).
        restUrl = URI:Parse("{&BASE-URL}/{&API-VERSION}/issue/" + pIssueId).
    END.

    restUrl:AddQuery("expand", "renderedBody").

    RUN put_update_request(hc,
                           restUrl,
                           creds,
                           commentBody,
                           OUTPUT commentBody).

    //commentBody:writefile('add-comment.json', yes).
END PROCEDURE.


PROCEDURE add_attachment:
    DEFINE INPUT  PARAMETER pIssueId        AS CHARACTER NO-UNDO.
    DEFINE INPUT  PARAMETER pAttachmentFile AS CHARACTER NO-UNDO.

    DEFINE VARIABLE attachmentBody AS MultipartEntity NO-UNDO.
    DEFINE VARIABLE respBody       AS JsonObject      NO-UNDO.
    DEFINE VARIABLE postUrl        AS URI             NO-UNDO.
    DEFINE VARIABLE part           AS MessagePart     NO-UNDO.
    DEFINE VARIABLE pos            AS INTEGER         NO-UNDO.

    postUrl = URI:Parse("{&BASE-URL}/{&API-VERSION}/issue/" + pIssueId + "/attachments").

    IF pAttachmentFile MATCHES "*\.pdf" then
        part = NEW MessagePart("application/pdf",
                               NEW FileInputStream(pAttachmentFile)).
    else
        part = NEW MessagePart("application/octet-stream",
                               NEW FileInputStream(pAttachmentFile)).

    pos = R-INDEX(REPLACE(pAttachmentFile, StringConstant:BACKSLASH, '/'), '/').
    IF pos GT 0 then
        pAttachmentFile = substring(pAttachmentFile, pos + 1).

    part:Headers:Put(HttpHeaderBuilder:Build("Content-Disposition")
                                    :Value("form-data")
                                    :AddParameter("name", "file")
                                    :AddParameter("filename", pAttachmentFile)
                                    :Header).

    attachmentBody = NEW MultipartEntity().
    attachmentBody:AddPart(part).

    RUN post_new_request (hc, postUrl, creds, attachmentBody, OUTPUT respBody).
END PROCEDURE.

PROCEDURE assign_issue:
    DEFINE INPUT  PARAMETER pIssueId AS CHARACTER NO-UNDO.
    DEFINE INPUT  PARAMETER pAssignee AS CHARACTER NO-UNDO.

    DEFINE VARIABLE putUrl AS URI        NO-UNDO.
    DEFINE VARIABLE body   AS JsonObject NO-UNDO.

    body = NEW JsonObject().

    // There are GDPR-related constraints on user the user name or email.
    // An error message is returned as JSON from the assignment operation:
    //  {"errorMessages":["'accountId' must be the only user identifying query parameter in GDPR strict mode."],"errors":{}}
    //body:Add("name", pAssignee).
    body:Add("accountId", pAssignee).

    putUrl = URI:Parse("{&BASE-URL}/{&API-VERSION}/issue/" + pIssueId + "/assignee").

    RUN put_update_request(hc, putUrl,  creds, body, OUTPUT body).
END PROCEDURE.

PROCEDURE get_assignable_users:
    DEFINE INPUT  PARAMETER pIssueId AS CHARACTER NO-UNDO.

    DEFINE VARIABLE getUrl AS URI           NO-UNDO.
    DEFINE VARIABLE body   AS JsonConstruct NO-UNDO.
    DEFINE VARIABLE users  AS JsonArray     NO-UNDO.
    DEFINE VARIABLE loop   AS INTEGER       NO-UNDO.
    DEFINE VARIABLE cnt    AS INTEGER       NO-UNDO.
    DEFINE VARIABLE aUser  AS JsonObject    NO-UNDO.
    DEFINE VARIABLE groups AS JsonObject    NO-UNDO.
    DEFINE VARIABLE jo     AS JsonObject    NO-UNDO.
    DEFINE VARIABLE ja     AS JsonArray     NO-UNDO.
    DEFINE VARIABLE loop2  AS INTEGER       NO-UNDO.
    DEFINE VARIABLE cnt2   AS INTEGER       NO-UNDO.

    getUrl = URI:Parse("{&BASE-URL}/{&API-VERSION}/user/assignable/search?issueKey=DEMO-1&query=").

    RUN get_request(hc, getUrl, creds, OUTPUT body).

    users = CAST(body, JsonArray).
    cnt = users:LENGTH.
    DO loop = 1 TO cnt:
        aUser = users:GetJsonObject(loop).

        /* Only assign to Consultingwerk users
           get the user details */
        RUN get_request(hc, URI:Parse(aUser:GetCharacter("self") + "&expand=groups"), creds, OUTPUT body).

        jo = CAST(body, JsonObject).
        groups = jo:GetJsonObject("groups").
        ja = groups:GetJsonArray("items").
        cnt2 = groups:GetInteger("size").
        DO loop2 = 1 TO cnt2:
            jo = ja:GetJsonObject(loop2).
            IF jo:GetCharacter("name") EQ "Consultingwerk" THEN
            DO:
                CREATE ttAssignableUser.
                ASSIGN ttAssignableUser.AccountId   = aUser:GetCharacter("accountId")
                       ttAssignableUser.DisplayName = aUser:GetCharacter("displayName")
                       ttAssignableUser.EmailAddress = aUser:GetCharacter("emailAddress")
                       .
                LEAVE.
            END.
        END.
    END.
END PROCEDURE.

PROCEDURE add_watcher:
    DEFINE INPUT  PARAMETER pIssueId AS CHARACTER NO-UNDO.
    DEFINE INPUT  PARAMETER pWatcher AS CHARACTER NO-UNDO.

    DEFINE VARIABLE data    AS JsonObject NO-UNDO.
    DEFINE VARIABLE strData AS String     NO-UNDO.

    // "peter"
    strData = NEW String(StringConstant:DOUBLE_QUOTE + pWatcher + StringConstant:DOUBLE_QUOTE).

    RUN post_new_request(hc,
                         URI:Parse("{&BASE-URL}/{&API-VERSION}/issue/" + pIssueId + "/watchers"),
                         creds,
                         strData,
                         OUTPUT data).

    //data:Writefile("add-watcher.json", yes).
END PROCEDURE.

PROCEDURE remove_watcher:
    DEFINE INPUT  PARAMETER pIssueId AS CHARACTER NO-UNDO.
    DEFINE INPUT  PARAMETER pWatcher AS CHARACTER NO-UNDO.

    DEFINE VARIABLE body   AS JsonConstruct NO-UNDO.

    RUN delete_request(hc,
                       URI:Parse("{&BASE-URL}/{&API-VERSION}/issue/" + pIssueId + "/watchers?username=" + pWatcher),
                       creds, ?, OUTPUT body).

    //body:writefile('remove-watcher.json', yes).
END PROCEDURE.

PROCEDURE create_subtask:
    DEFINE INPUT  PARAMETER pParentIssue AS CHARACTER NO-UNDO.
    DEFINE INPUT  PARAMETER pSummary     AS CHARACTER NO-UNDO.
    DEFINE INPUT  PARAMETER pDescription AS CHARACTER NO-UNDO.
    DEFINE INPUT  PARAMETER pReporter    AS CHARACTER NO-UNDO.
    DEFINE INPUT  PARAMETER pAssignee    AS CHARACTER NO-UNDO.
    DEFINE OUTPUT PARAMETER pIssueKey    AS CHARACTER NO-UNDO.

    DEFINE VARIABLE issueJson   AS JsonObject NO-UNDO.
    DEFINE VARIABLE issueFields AS JsonObject NO-UNDO.
    DEFINE VARIABLE jo          AS JsonObject NO-UNDO.

    issueJson = NEW JsonObject().
    issueFields = NEW JsonObject().
    issueJson:Add("fields", issueFields).

    jo = NEW JsonObject().
    issueFields:Add("project", jo).
        jo:Add("key", "DEMO").

    jo = NEW JsonObject().
    issueFields:Add("parent", jo).
        jo:Add("key", pParentIssue).

    issueFields:Add("summary", pSummary).
    issueFields:Add("description", pDescription).

    jo = NEW JsonObject().
    issueFields:Add("issuetype", jo).
        jo:Add("id", "10637").      // SUBTASK

    jo = NEW JsonObject().
    issueFields:Add("reporter", jo).
        jo:Add("accountId", pReporter).

    jo = NEW JsonObject().
    issueFields:Add("assignee", jo).
        jo:Add("accountId", pAssignee).

    RUN post_new_request(hc,
                         URI:Parse("{&BASE-URL}/{&API-VERSION}/issue"),
                         creds,
                         issueJson,
                         OUTPUT issueJson).

    IF issueJson:Has("key") THEN
        pIssueKey = issueJson:GetCharacter("key").
    ELSE
        pIssueKey = ?.
END PROCEDURE.

PROCEDURE create_issue:
    DEFINE INPUT  PARAMETER pIssueType   AS CHARACTER NO-UNDO.
    DEFINE INPUT  PARAMETER pSummary     AS CHARACTER NO-UNDO.
    DEFINE INPUT  PARAMETER pDescription AS CHARACTER NO-UNDO.
    DEFINE INPUT  PARAMETER pReporter    AS CHARACTER NO-UNDO.
    DEFINE INPUT  PARAMETER pAssignee    AS CHARACTER NO-UNDO.
    DEFINE OUTPUT PARAMETER pIssueKey    AS CHARACTER NO-UNDO.

    DEFINE VARIABLE issueJson   AS JsonObject NO-UNDO.
    DEFINE VARIABLE issueFields AS JsonObject NO-UNDO.
    DEFINE VARIABLE jo          AS JsonObject NO-UNDO.

    issueJson = NEW JsonObject().
    issueFields = NEW JsonObject().
    issueJson:Add("fields", issueFields).

    jo = NEW JsonObject().
    issueFields:Add("project", jo).
        jo:Add("key", "DEMO").

    issueFields:Add("summary", pSummary).
    issueFields:Add("description", pDescription).

    jo = NEW JsonObject().
    issueFields:Add("issuetype", jo).

    CASE pIssueType:
        WHEN "Story" THEN jo:Add("id", "10633").
        WHEN "Task"  THEN jo:Add("id", "10634").
        WHEN "Bug"   THEN jo:Add("id", "10635").
        WHEN "Epic"  THEN jo:Add("id", "10636").
    END CASE.

    jo = NEW JsonObject().
    issueFields:Add("reporter", jo).
        jo:Add("accountId", pReporter).

    jo = NEW JsonObject().
    issueFields:Add("assignee", jo).
        jo:Add("accountId", pAssignee).

    RUN post_new_request(hc,
                         URI:Parse("{&BASE-URL}/{&API-VERSION}/issue"),
                         creds,
                         issueJson,
                         OUTPUT issueJson).

    IF issueJson:Has("key") THEN
        pIssueKey = issueJson:GetCharacter("key").
    ELSE
        pIssueKey = ?.
END PROCEDURE.

PROCEDURE get_create_metadata:
    DEFINE OUTPUT PARAMETER pData AS JsonObject NO-UNDO.

    DEFINE VARIABLE body AS JsonConstruct NO-UNDO.

    // https://developer.atlassian.com/server/jira/platform/updating-an-issue-via-the-jira-rest-apis-6848604/
    RUN get_request(hc,
                    URI:Parse("{&BASE-URL}/{&API-VERSION}/issue/createmeta?projectKeys=DEMO&expand=projects.issuetypes.fields"),
                    creds,
                    OUTPUT body).

    IF TYPE-OF(body, JsonObject) THEN
        pData = CAST(body, JsonObject).
    ELSE
        pData = NEW JsonObject().
END PROCEDURE.

PROCEDURE update_status:
    DEFINE INPUT PARAMETER pIssueKey AS CHARACTER NO-UNDO.
    DEFINE INPUT PARAMETER pStatus   AS CHARACTER NO-UNDO.

    DEFINE VARIABLE issueJson    AS JsonObject    NO-UNDO.
    DEFINE VARIABLE body         AS JsonConstruct NO-UNDO.
    DEFINE VARIABLE ja           AS JsonArray     NO-UNDO.
    DEFINE VARIABLE jo           AS JsonObject    NO-UNDO.
    DEFINE VARIABLE jo2          AS JsonObject    NO-UNDO.
    DEFINE VARIABLE loop         AS INTEGER       NO-UNDO.
    DEFINE VARIABLE cnt          AS INTEGER       NO-UNDO.
    DEFINE VARIABLE transitionId AS CHARACTER     NO-UNDO.

    /* Get the valid states for this ticket */
    RUN get_request(hc,
                    URI:Parse("{&BASE-URL}/{&API-VERSION}/issue/" + pIssueKey + "/transitions"),
                    creds,
                    OUTPUT body).

    IF TYPE-OF(body, JsonObject) THEN
    DO:
        jo = CAST(body, JsonObject).
        ja = jo:GetJsonArray("transitions").
        cnt = ja:Length.
    END.
    ELSE
        cnt = ?.

    DO loop = 1 TO cnt:
        jo = ja:GetJsonObject(loop).
        IF jo:GetCharacter("name") EQ pStatus THEN
        DO:
            transitionId = jo:GetCharacter("id").
            LEAVE.
        END.
    END.

    /* Update the ticket */
    issueJson = NEW JsonObject().
    jo = NEW JsonObject().
    issueJson:Add("transition", jo).
        jo:Add("id", transitionId).

    RUN post_new_request(hc,
                         URI:Parse("{&BASE-URL}/{&API-VERSION}/issue/" + pIssueKey + "/transitions"),
                         creds,
                         issueJson,
                         OUTPUT issueJson).

END PROCEDURE.

PROCEDURE link_issues:
    DEFINE INPUT PARAMETER pInwardIssueKey  AS CHARACTER NO-UNDO.
    DEFINE INPUT PARAMETER pLinkType        AS CHARACTER NO-UNDO.
    DEFINE INPUT PARAMETER pOutwardIssueKey AS CHARACTER NO-UNDO.

    DEFINE VARIABLE data AS JsonObject NO-UNDO.
    DEFINE VARIABLE jo   AS JsonObject NO-UNDO.

    data = NEW JsonObject().
    jo = NEW JsonObject().
    data:Add("type", jo).
        jo:Add("name", pLinkType).

    jo = NEW JsonObject().
    data:Add("inwardIssue", jo).
        jo:Add("key", pInwardIssueKey).

    jo = NEW JsonObject().
    data:Add("outwardIssue", jo).
        jo:Add("key", pOutwardIssueKey).

    RUN post_new_request(hc,
                         URI:Parse("{&BASE-URL}/{&API-VERSION}/issueLink"),
                         creds,
                         data,
                         OUTPUT data).

END PROCEDURE.

PROCEDURE link_github_issue:
    DEFINE INPUT PARAMETER pIssueKey          AS CHARACTER NO-UNDO.
    DEFINE INPUT PARAMETER pGithubIssueNumber AS INTEGER NO-UNDO.

    DEFINE VARIABLE data AS JsonObject NO-UNDO.
    DEFINE VARIABLE jo   AS JsonObject NO-UNDO.
    DEFINE VARIABLE jo2  AS JsonObject NO-UNDO.

    data = NEW JsonObject().
    data:Add("globalId", "issue:github.com/4gl-fanatics/jira_http/issues:" + string(pGithubIssueNumber)).

    jo = NEW JsonObject().
        jo:Add("url", "https://github.com/4gl-fanatics/jira_http/issues/" + string(pGithubIssueNumber)).
        jo:Add("title", "Github Issue (" + STRING(pGithubIssueNumber) + ")").
    data:Add("object", jo).

    jo = NEW JsonObject().
        jo:Add("name", "GitHub Issues").
        jo:Add("type", "jira-http-issue").
    data:Add("application", jo).

    RUN post_new_request(hc,
                         URI:Parse("{&BASE-URL}/{&API-VERSION}/issue/" + pIssueKey + "/remotelink"),
                         creds,
                         data,
                         OUTPUT data).
END PROCEDURE.

PROCEDURE add_web_link:
    DEFINE INPUT PARAMETER pIssueKey AS CHARACTER NO-UNDO.
    DEFINE INPUT PARAMETER pUrl      AS CHARACTER NO-UNDO.
    DEFINE INPUT PARAMETER pTitle    AS CHARACTER NO-UNDO.

    DEFINE VARIABLE data AS JsonObject NO-UNDO.
    DEFINE VARIABLE jo   AS JsonObject NO-UNDO.
    DEFINE VARIABLE jo2  AS JsonObject NO-UNDO.

    data = NEW JsonObject().
    jo = NEW JsonObject().
        jo:Add("url", pUrl).
        jo:Add("title", pTitle).
    data:Add("object", jo).

    RUN post_new_request(hc,
                         URI:Parse("{&BASE-URL}/{&API-VERSION}/issue/" + pIssueKey + "/remotelink"),
                         creds,
                         data,
                         OUTPUT data).
END PROCEDURE.