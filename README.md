# Accessing JIRA via the ABL HTTP client
This repo contains sample code for interacting with Jira using the ABL HTTP Client, as presented in various presentations.

## Useful links
| | |
| ---- |  ---- |
| REST API  | https://docs.atlassian.com/software/jira/docs/api/REST/7.6.1 |
| Atlassian Document Format | https://developer.atlassian.com/cloud/jira/platform/apis/document/structure/ |

## Common functions
The `common_functions.i` include contains a number of shared functions. It is included in the  `get_release_notes.p` and `update_ticket.p` programs. Each internal procedure has a varying parameters.

| Internal procedure | Description |
| ---- |  ---- |
| build_client | Creates an instance of the HTTP client to communicate with the Jira instance. |
| delete_request | Sends an HTTP DELETE request to the Jira instance, at a specified URL |
| get_credentials | Reads the `jira-credentials.json` file (see below) |
| get_request | Sends an HTTP GET request to the Jira instance, at a specified URL. The responses are limited to the first 1000 records returned (via the `startAt` and `maxResults` query parameters) |
| post_new_request | Sends an HTTP POST request to the Jira instance, at a specified URL. An `X-Atlassian-Token:no-check` header is sent to avoid "XSRF check failed" errors)|
| put_update_request | Sends an HTTP PUT request to the Jira instance, at a specified URL. |

## Other
The `jira-credentials.json` file contains the username and password used to create a basic authentication header. The value for the password is an API token generated per the instructions at https://support.atlassian.com/atlassian-account/docs/manage-api-tokens-for-your-atlassian-account/#Use-an-API-token .

The programs in the `OpenEdge` folder contain patches issues in to the HTTP client; these may be fixed in future releases. This code was created and tested against OpenEdge 12.5.1.

The `hctracing.config` file enables the client tracing. This can be disabled by either setting the value of the `enabled` property to `false` in the config file, or by passing `FALSE` to the `build_client` method.

## Getting release notes from Jira

The `get_release_notes.p` program queries Consultingwerk's Jira instance, and builds a ProDataSet containing release note data for the tickets for a release. The ProDataSet contains 2 temp-tables: ttRelnote and ttAttachment. The former contains the release note texts, and the latter zero or more attachements for the ticket. Jira tickets are filtered by type (only Bug and Improvement are kept), and by project (SCL) and release.

Example JSON output
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

## Writing to Jira
The `update_ticket.p` program has a number of internal procedures that are used to create and update Jira tickets. The program updates the `DEMO` project in Consultingwerk's Jira instance. Each procedure has varying parameters.

| Internal procedure | Description |
| ---- |  ---- |
| add_comment | Adds a comment to an issue. This can use either the "Add Comment" or the "Edit Issue" approach |
| add_attachment | Adds a file as an attachment to an issue |
| add_watcher | Adds a user to the list of watchers for an issue |
| add_web_link | Adds a remote (non-Jira) web link to an issue |
| assign_issue | Assigned an issue to a user. |
| create_issue | Creates an issue of a specified type in the DEMO project |
| create_subtask | Creates a subtask for an issue |
| get_assignable_users | Builds a temp-table of users to which an issue can be assigned. In this case, only users belonging to the "Consultingwerk" group can be assigned issues. |
| get_create_metadata | Returns the metadata relating to issue creation in the DEMO project. |
| get_issue_id | Returns the Jira issue ID based on a key |
| link_issues | Links two issues (eg blocks or clones) |
| link_github_issue |  Adds a remote (non-Jira) web link to an issue. This links are based on the Github issue number in this project. These links will be grouped under a `GitHub Issues` heading|
| remove_watcher | Removes a user from the list of watchers for an issue |
| update_status | Transitions an issue to another status. |

