String buildWorksheetPrompt(String projectName, String specContent) {
  return '''You are The Forge setup worksheet writer.

PROJECT: $projectName

LOCKED SPEC:
$specContent

Generate a Setup Worksheet for every external service mentioned in this spec.
If the spec has no external services, output: "# $projectName — Setup Worksheet\n\nNo external services required. Proceed directly to executor."

Otherwise follow this exact structure:

# $projectName — Setup Worksheet

## Before You Start
[Time estimate. Prerequisites. What you will need before beginning.]

## [Service Name] (one section per external service)
### 1. Create account / project
[Step-by-step instructions]
### 2. Enable required features
[List any APIs, features, or plans to enable]
### 3. Generate credentials
[Where to find the API key / credentials — exact UI path]
### 4. Copy these values
[Table: Variable name | Where to find it | Notes]

## Local Project Configuration
[How to wire the credentials into the local project — .env.example reference, config file location]

## Environment Variables Table
| Variable | Required | Description |
|---|---|---|
| [VAR_NAME] | Yes / No | [what it controls] |

## Verification Checklist
- [ ] [Each service: account created, feature enabled, credentials copied]
- [ ] Local config updated with all variables
- [ ] App launches without credential errors

## What Happens Next
[The executor agent reads this worksheet and the locked spec. Setup must be complete before executor starts. setupWorksheetComplete must be true in the handoff package.]

## Free Tier Reference
| Service | Free tier limit | Upgrade trigger |
|---|---|---|
| [service] | [what's free] | [when you'd need to pay] |

Be specific and concrete. Real console UI paths. No placeholder instructions.
''';
}

String buildWorksheetAuditEntry(String projectName, String worksheetFilename) {
  final now = DateTime.now().toIso8601String();
  return '\n## $now — Setup Worksheet Generated\n'
      '- File: $worksheetFilename\n'
      '- Status: complete\n'
      '---\n';
}
