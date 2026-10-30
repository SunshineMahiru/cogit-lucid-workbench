import { describe, expect, it } from '@ohos/hypium';
import { ThresholdCalibrationAnalyzer } from '../../../main/ets/analysis/calibration/ThresholdCalibrationAnalyzer';
import { isExportable } from '../../../main/ets/export/ExportFilter';
import { SecurityLevel } from '../../../main/ets/model/SecurityLevel';
import { validatePredictionDraft } from '../../../main/ets/prediction/PredictionValidation';

export default function abilityTest() {
  describe('AnalysisRules', () => {
    it('rejectsEmptyPredictionTarget', 0, () => {
      const errors = validatePredictionDraft({
        target: '',
        judgment: '判断',
        confidence: 70,
        reason: '',
        settlementDate: '2099-01-01'
      }, Date.now());
      expect(errors.target.length > 0).assertTrue();
    });

    it('acceptsCompletePredictionDraft', 0, () => {
      const errors = validatePredictionDraft({
        target: '预测对象',
        judgment: '判断',
        confidence: 70,
        reason: '理由',
        settlementDate: '2099-01-01'
      }, Date.now());
      expect(errors.target).assertEqual('');
      expect(errors.judgment).assertEqual('');
      expect(errors.confidence).assertEqual('');
      expect(errors.settlementDate).assertEqual('');
    });

    it('calibratesConfidenceBands', 0, () => {
      const report = new ThresholdCalibrationAnalyzer().analyze([
        { confidence: 50, hit: false },
        { confidence: 100, hit: true }
      ], { now: Date.now() });
      expect(report.settled).assertEqual(2);
      expect(report.hits).assertEqual(1);
      expect(report.brierScore).assertEqual(0.125);
      expect(report.buckets.length).assertEqual(4);
    });

    it('exportsOnlyNonSealedRecords', 0, () => {
      expect(isExportable(SecurityLevel.SEALED)).assertFalse();
      expect(isExportable(SecurityLevel.LOCAL_ONLY)).assertTrue();
    });
  });
}
