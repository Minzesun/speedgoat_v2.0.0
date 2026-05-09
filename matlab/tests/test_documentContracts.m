function tests = test_documentContracts
tests = functiontests(localfunctions);
end

function testDocumentationContractsStayOperatorFacing(testCase)
projectRoot = string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
runbook = fileread(fullfile(projectRoot, 'docs', 'field_validation', 'speedgoat_v2_minimal.md'));

verifyTrue(testCase, contains(runbook, '连接目标机'));
verifyTrue(testCase, contains(runbook, '点击 `Start`'));
verifyTrue(testCase, contains(runbook, '确认 `ready_to_run == 1`'));
verifyTrue(testCase, contains(runbook, '人工把速度降回 `0`'));
boundary = fileread(fullfile(projectRoot, 'docs', 'reference', 'speedgoat_v2_boundary_statement.md'));

verifyTrue(testCase, contains(boundary, '不改 ENI'));
verifyTrue(testCase, contains(boundary, '不做 MATLAB helper'));
verifyTrue(testCase, contains(boundary, '不做 TwinCAT'));
verifyTrue(testCase, contains(boundary, 'demo_stable'));
verifyTrue(testCase, contains(boundary, '1702h Outputs + 1B04h Inputs'));
verifyTrue(testCase, contains(boundary, '只支持单轴 CSV'));
verifyTrue(testCase, contains(boundary, 'ready_to_run'));
verifyTrue(testCase, contains(boundary, '非零速度仍由人工给定'));

reference = fileread(fullfile(projectRoot, 'docs', 'reference', 'speedgoat_v2_signal_parameter_reference.md'));

verifyTrue(testCase, contains(reference, '| Name | Meaning | Source | slrtExplorer 里怎么看 | 出问题查 |'));
verifyTrue(testCase, contains(reference, 'slrtExplorer'));
verifyTrue(testCase, contains(reference, 'Signals'));
verifyTrue(testCase, contains(reference, 'Diagnostics'));
verifyTrue(testCase, contains(reference, 'Commands'));
verifyTrue(testCase, contains(reference, '出问题查'));
verifyTrue(testCase, contains(reference, 'EtherCAT 手册'));
verifyTrue(testCase, contains(reference, 'SV660N 手册'));
verifyTrue(testCase, contains(reference, '603Fh'));
verifyTrue(testCase, contains(reference, '6041h'));
verifyTrue(testCase, contains(reference, '6064h'));
verifyTrue(testCase, contains(reference, '60FFh'));
end
