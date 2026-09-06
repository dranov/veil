import type { Html } from './htmlDisplay';

export interface InductionMetadataData {
  stmtDerivedFrom?: string[];
  property: string;
  kind?: 'primary' | 'alternative';
  action: string;
  style?: 'wp' | 'tr';
}

export interface TraceMetadataData {
  traceName: string;
  numTransitions: number;
  isExpectedSat: boolean;
}

export interface VCMetadata {
  type: 'induction' | 'trace';
  data: InductionMetadataData | TraceMetadataData;
}

export interface StructuredJson {
  theory: Record<string, unknown>;
  preState: Record<string, unknown>;
  postState: Record<string, unknown> | null;
  label: Record<string, unknown>;
  instantiation: Record<string, unknown>;
  extraVals?: Record<string, unknown>;
  extraSorts?: Record<string, unknown>;
}

export interface Counterexample {
  model?: any;
  structuredJson?: StructuredJson;
  html: Html | string;  // Can be either structured Html or raw HTML string
}

export interface DischargerResultData {
  kind: string;
  counterexamples?: Counterexample[];
  reasons?: string[];
}

export interface DischargerResult {
  time: number;
  status: string;
  data?: DischargerResultData;
  exceptions?: string[];
}

export interface DischargerStatusFinished {
  finished: {
    res: DischargerResult;
  };
}

export type DischargerStatus = string | DischargerStatusFinished;

export interface Discharger {
  id: number;
  name: string;
  isInteractive: boolean;
  status: DischargerStatus;
  time: number | null;
  startTime: number | null;
  result?: DischargerResult | null;
}

export interface VCTiming {
  totalTime: number | null;
  successfulDischargerTime?: number;
  successfulDischargerId?: number;
  dischargers: Discharger[];
}

export interface VerificationCondition {
  id: number;
  name: string;
  status: 'proven' | 'disproven' | 'unknown' | 'error' | 'timeout' | null;
  metadata: VCMetadata;
  timing: VCTiming;
  alternativeFor?: number | null;
  isDormant?: boolean;
  /** Theorem text for inserting into the editor (only for non-proven VCs) */
  theoremText?: string | null;
  /** True when this VC's selected successful proof witness contains `sorry`. */
  proofHasSorry?: boolean;
}

export interface VerificationResults {
  vcs: VerificationCondition[];
  totalVCs: number;
  totalSolved: number;
  totalDischarged: number;
  serverTime: number;
}

export interface InsertPosition {
  line: number;
  character: number;
}

export interface VerificationResultsProps {
  results: VerificationResults;
  /** Position after #check_invariants for theorem insertion */
  theoremInsertPos: InsertPosition;
  /** Position before #gen_spec for option insertion */
  optionInsertPos?: InsertPosition | null;
  /** Document URI for edit operations */
  documentUri: string;
}

