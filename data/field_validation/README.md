# data/field_validation

This folder is for Speedgoat field-validation captures.

Use `docs/field_validation/speedgoat_v2_position_identification.md` before recording position-identification data.
Use `docs/field_validation/speedgoat_v2_position_tuning.md` before recording PT-8 position-loop tuning data.
Capture the raw signals in `slrtExplorer` and export them with the same basename for:

- `.mat` raw MATLAB capture
- `.csv` exported table for quick review
- `.md` metadata note for operator-readable context

Recommended basename:

```text
YYYYMMDD_axis1_<sequence>_<direction>_v<speed>_tr<travel>
```

Example:

```text
20260510_axis1_step_pos_v200_tr1000.mat
20260510_axis1_step_pos_v200_tr1000.csv
20260510_axis1_step_pos_v200_tr1000.md
```

Do not keep a capture without the matching metadata note. If a trial fails, still keep the `.md` note and record why it stopped.

After export, first run `sgv2.analysis.summarizeIdentificationCapture(capture)`. If the summary looks safe, run `sgv2.analysis.fitIdentificationRelationship(capture)` to estimate the first `K_cmd / B_cmd / RSquared` values for the inverse-model design.
If you need to suppress a direction change or other start/stop transient in the offline fit, record `IdentificationTransientGuardSamples` in the `.md` note and keep the value small and explicit.
