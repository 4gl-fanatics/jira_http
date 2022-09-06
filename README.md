# Accessing JIRA via the ABL HTTP client
This repo contains the source and slides presented at the 2022 PUG Challenge in Vienna.

## Getting release notes from Jira

The `get_release_notes.p` program queries Consultingwerk's Jira instance, and builds a ProDataSet containing release note data for the tickets for a release. The ProDatASet contains 2 temp-tables: ttRelnote and ttAttachment. The former contains the release note texts, and the latter zero or more attachements for the ticket. Jira tickets are filtered by type (only Bug and Improvement are kept), and by project (SCL) and release.


Example JSON writted from 
```json
{
    "dsRelnote": {
        "releaseNotes": [
            {
                "JiraId": "SCL-3675",
                "IssueType": "Improvement",
                "IssueDescription": "Potential improvements when retrieving field values.",
                "NoteTitle": "Investigate potential improvements to the DatasetModel performance",
                "NoteDescription": "."
            },
            {
                "JiraId": "SCL-3742",
                "IssueType": "Bug",
                "IssueDescription": "!image-20220816-034509.png|width=904,height=556!",
                "NoteTitle": "Exporting of smartrepo files from GUI thin client fails with Database smartdb not connected",
                "NoteDescription": ".",
                "attachments": [
                    {
                        "JiraId": "SCL-3742",
                        "Attachment": "<base63-encoded BLOB field>",
                        "ContentType": "image\/png",
                        "Filename": "image-20220816-034509.png",
                        "AttachmentUrl": "https:\/\/consultingwerk.atlassian.net\/rest\/api\/2\/attachment\/content\/28632"
                    }
                ]
            }
        ]
    }
}
```


This code will need to be modified to be used on other Jira instances, particularly where Consultingwerk uses custom fields (the names of these fields may change in different Jira instances). A number of `.json` files are created during the run of the program - these were used during the talk to demo the responses.

The `jira-credentials.json` file contains the username and password used to create a basic authentication header. The value for the password is an API token generated per the instructions at https://support.atlassian.com/atlassian-account/docs/manage-api-tokens-for-your-atlassian-account/#Use-an-API-token .

The programs in the `OpenEdge` folder contain patches issues in to the HTTP client; these may be fixed in future releases. This code was created and tested against OpenEdge 12.5.1.

The `hctracing.config` file enables the client tracing. This can be disabled by either passing `false` to the `AllowTracing` builder method in the `get_release_notes.p` program, or by setting the value of the `enabled` property to `false` in the config file.


