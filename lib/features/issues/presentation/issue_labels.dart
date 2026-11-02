import '../../../core/settings/app_preferences.dart';
import '../domain/farmer_issue.dart';

String issueKindLabel(IssueKind kind, AppPreferences p) => switch (kind) {
  IssueKind.registration => p.text(
    'Registration correction',
    'पंजीकरण में सुधार',
  ),
  IssueKind.token => p.text('Token / centre visit', 'टोकन / केंद्र की यात्रा'),
  IssueKind.weighing => p.text('Weighing / quality', 'तौल / गुणवत्ता'),
  IssueKind.payment => p.text('Payment follow-up', 'भुगतान की जानकारी'),
  IssueKind.other => p.text('Other problem', 'अन्य समस्या'),
};
String evidenceLabel(String key, AppPreferences p) => switch (key) {
  'token' => p.text(
    'Official token / registration slip kept',
    'सरकारी टोकन / पंजीकरण पर्ची रखी है',
  ),
  'weighing' => p.text(
    'Weighing / quality receipt kept',
    'तौल / गुणवत्ता की रसीद रखी है',
  ),
  'purchase' => p.text('Purchase receipt kept', 'खरीदी रसीद रखी है'),
  _ => p.text(
    'Official acknowledgement / reference kept',
    'सरकारी पावती / संदर्भ रखा है',
  ),
};
String issueDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String issueSummary(FarmerIssue issue, AppPreferences p) => [
  p.text(
    'Krishi Queue — personal follow-up note',
    'कृषि क्यू — व्यक्तिगत फॉलो-अप नोट',
  ),
  p.text(
    'This note has not been submitted by the app to any office.',
    'ऐप ने यह नोट किसी कार्यालय में जमा नहीं किया है।',
  ),
  '${p.text('Topic', 'विषय')}: ${issueKindLabel(issue.kind, p)}',
  '${p.text('Centre / office', 'केंद्र / कार्यालय')}: ${issue.centre}',
  '${p.text('Date of problem', 'समस्या की तारीख')}: ${issueDate(issue.occurredOn)}',
  '${p.text('What happened', 'क्या हुआ')}: ${issue.description}',
  if (issue.officialReference.isNotEmpty)
    '${p.text('Reference entered by you; not verified', 'आपके द्वारा लिखा संदर्भ; सत्यापित नहीं')}: ${issue.officialReference}',
  '${p.text('Your status', 'आपकी लिखी स्थिति')}: ${issue.resolved ? p.text('Resolved', 'हल हुआ') : p.text('Needs follow-up', 'फॉलो-अप चाहिए')}',
  if (issue.followUpOn != null)
    '${p.text('Your follow-up date', 'आपकी फॉलो-अप तारीख')}: ${issueDate(issue.followUpOn!)}',
  for (final key in issueEvidence)
    '${issue.evidence.contains(key) ? '[x]' : '[ ]'} ${evidenceLabel(key, p)}',
  for (final entry in issue.updates) '${issueDate(entry.date)}: ${entry.note}',
  p.text(
    'Keep original receipts. Contact the responsible office through its official channel.',
    'मूल रसीदें रखें। संबंधित कार्यालय से उसके सरकारी माध्यम से संपर्क करें।',
  ),
].join('\n');
