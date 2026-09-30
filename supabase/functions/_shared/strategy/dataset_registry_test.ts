import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import {
  getDataset, isKnownDataset, SYNTHETIC_5MIN_DATASET, SYNTHETIC_5MIN_HOLDOUT_SEGMENT, SYNTHETIC_5MIN_RESEARCH_SEGMENT, WIN1_REAL_DATASET,
} from './dataset_registry.ts';

Deno.test('DR-01 known dataset ids resolve to their real records', () => {
  assertEquals(getDataset('synthetic-fixture-5min-v1'), SYNTHETIC_5MIN_DATASET);
  assertEquals(getDataset('win1-5min-qt01c3'), WIN1_REAL_DATASET);
});

Deno.test('DR-02 an unknown/forged dataset id resolves to nothing -- never a guessed path', () => {
  assertEquals(getDataset('../../etc/passwd'), undefined);
  assertEquals(getDataset('C:/Users/jpaul/anything.csv'), undefined);
  assert(!isKnownDataset('../../etc/passwd'));
});

Deno.test('DR-03 the real WIN1! dataset is marked UNCLEAR_NOT_DISTRIBUTED and carries no in-process rows', () => {
  assertEquals(WIN1_REAL_DATASET.licenseStatus, 'UNCLEAR_NOT_DISTRIBUTED');
  assertEquals(WIN1_REAL_DATASET.rowsAvailableInProcess, false);
});

Deno.test('DR-04 the synthetic fixture is marked as such, not as real/user-provided data', () => {
  assertEquals(SYNTHETIC_5MIN_DATASET.licenseStatus, 'SYNTHETIC_FIXTURE');
  assertEquals(SYNTHETIC_5MIN_DATASET.rowsAvailableInProcess, true);
});

Deno.test('DR-05 (§14) the research/holdout segment records resolve and both trace back to the same parent dataset', () => {
  assertEquals(getDataset('synthetic-fixture-5min-v1-research'), SYNTHETIC_5MIN_RESEARCH_SEGMENT);
  assertEquals(getDataset('synthetic-fixture-5min-v1-holdout'), SYNTHETIC_5MIN_HOLDOUT_SEGMENT);
  assertEquals(SYNTHETIC_5MIN_RESEARCH_SEGMENT.segmentOf, SYNTHETIC_5MIN_DATASET.datasetId);
  assertEquals(SYNTHETIC_5MIN_HOLDOUT_SEGMENT.segmentOf, SYNTHETIC_5MIN_DATASET.datasetId);
});

Deno.test('DR-06 the research segment is chronologically entirely before the holdout segment', () => {
  assert(Date.parse(SYNTHETIC_5MIN_RESEARCH_SEGMENT.periodEnd) < Date.parse(SYNTHETIC_5MIN_HOLDOUT_SEGMENT.periodStart));
});
