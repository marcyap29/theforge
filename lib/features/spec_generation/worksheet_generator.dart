// Extracts only the spec sections relevant to service setup.
// Completion Criteria (§5), Static Content (§6), Open Flags (§9), and
// v2 Architecture Notes (§10) contain no service or credential information
// and are excluded to reduce prompt size by ~40-60%.
String _worksheetContext(String specContent) {
  const relevant = ['## 1.', '## 2.', '## 3.', '## 4.', '## 7.', '## 8.'];
  final buffer = StringBuffer();
  for (final header in relevant) {
    final start = specContent.indexOf(header);
    if (start < 0) continue;
    final nextHeader = specContent.indexOf('\n## ', start + 1);
    final end = nextHeader < 0 ? specContent.length : nextHeader;
    buffer.writeln(specContent.substring(start, end).trim());
    buffer.writeln();
  }
  return buffer.isEmpty ? specContent : buffer.toString().trim();
}

String buildWorksheetPrompt(String projectName, String specContent) {
  final context = _worksheetContext(specContent);
  return '''You are The Forge setup worksheet writer.

PROJECT: $projectName

LOCKED SPEC:
$context

Generate a Setup Worksheet for every external service mentioned in this spec.
If the spec has no external services, skip the per-service sections but still output the full structure below (Before You Start, Local Project Configuration, Environment Variables Table, Verification Checklist, What Happens Next, Free Tier Reference). Never output a one-liner — always produce the complete worksheet.

Follow this exact structure:

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
