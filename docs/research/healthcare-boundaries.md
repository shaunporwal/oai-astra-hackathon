# Healthcare development boundaries

Checked 2026-09-10 in response to the user's question. Healthcare is not a blanket prohibition on software development: capture, segmentation, dataset preparation, research model training, and offline evaluation can proceed. The current capture-usability milestone was an engineering scope decision, not a prohibition on diagnostic-model research.

OpenAI's [usage policies](https://openai.com/policies/usage-policies/) restrict tailored medical advice requiring a license without appropriate licensed-professional involvement and automation of high-stakes medical decisions without human review. These restrictions concern how a system is used; a disclaimer does not replace the required involvement. Manual assistant predictions are not independent clinical reference labels.

Separately, US software intended to analyze medical images for diagnosis may fall under medical-device oversight. The exact pathway depends on intended use and functionality; this note is not a legal classification of the project. See the [FDA clinical decision support navigator](https://www.fda.gov/medical-devices/digital-health-center-excellence/step-6-software-function-intended-provide-clinical-decision-support).

No task refusal or approval-review rejection has occurred. Development can continue; deployment as a patient-facing diagnostic product needs separate clinical, privacy, and regulatory assessment.
