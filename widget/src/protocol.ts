import type { Html } from './htmlDisplay';

export interface InductionMetadataData {
  stmtDerivedFrom?: string[];
  property: string;
  kind?: 'primary' | 'alternative' | 'derived';
  action: string;
  style?: 'wp' | 'tr';
}

export interface TraceMetadataData {
  traceName: string;
  numTransitions: number;
  isExpectedSat: boolean;
}

export type VCMetadata =
  | { type: 'induction'; data: InductionMetadataData }
  | { type: 'trace'; data: TraceMetadataData };

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
  insertionSourceHash: string;
}


export interface ParsedState {
  index: number;
  tag?: string; // Optional tag associated with this state (e.g. transition/action label)
  fields: Record<string, unknown>;
  failing?: boolean; // True if an assertion failed while executing the transition to this state
}
export type Trace = ParsedState[];

export type ViolationKind = "assumption_failure" | "safety_failure" | "deadlock" | "assertion_failure" | "initialization_failure";

export interface AssertionInfo {
  procedureName: string;
  moduleName: string;
  line: number;
  column: number;
}

export interface Violation {
  kind: ViolationKind;
  violates?: string[]; // Array of violated property names (only present for safety_failure)
  exception_id?: number; // Only present for assertion_failure
  assertion_info?: AssertionInfo; // Only present for assertion_failure
}

export interface EarlyTerminationCondition {
  kind: "found_violating_state" | "deadlock_occurred" | "reached_depth_bound";
  depth?: number;
}

export interface TerminationReason {
  kind: "explored_all_reachable_states" | "early_termination";
  condition?: EarlyTerminationCondition;
}

export interface TraceData {
  theory: Record<string, unknown>;
  states: Array<{
    index: number;
    fields: Record<string, unknown>;
    transition: unknown;
    failing?: boolean;
  }>;
  instantiation?: Record<string, unknown>;
  extraVals?: Record<string, unknown>;
}

export type ModelCheckingResult =
  | { result: "found_trace"; trace: TraceData }
  | { error: string }
  | {
      result: "found_violation";
      violation: Violation;
      initialization?: {theory: Record<string, unknown>; state: Record<string, unknown>};
      trace: TraceData | null;
    }
  | {
      result: "no_violation_found";
      explored_states: number;
      termination_reason: TerminationReason;
      trace?: TraceData | null;
    }
  | {
      result: "cancelled";
    }
  | {
      // Trace-only data without a result (for displaying execution traces)
      trace: TraceData;
    };

export interface ModelCheckerViewProps {
  result: ModelCheckingResult;
  layout?: "vertical" | "horizontal";
  rawHtml?: Html;
}
