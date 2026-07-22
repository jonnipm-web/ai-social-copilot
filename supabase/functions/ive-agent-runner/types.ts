/**
 * ive-agent-runner — Shared Types
 *
 * Todos os tipos compartilhados entre os módulos do agent runner.
 * Nenhuma lógica de negócio aqui.
 */

// ── Request ────────────────────────────────────────────────────────────────────

export interface AgentRequestBody {
  message:                string;
  project_id?:            string;
  route?:                 string;
  screen_name?:           string;
  selected_entity_type?:  string;
  selected_entity_id?:    string;
  context_version?:       string;
  context?:               Record<string, unknown>;
  history?:               Array<{ role: string; content: string }>;
  recent_questions?:      string[];
  client_correlation_id?: string;
}

// ── Database row shapes (subset of columns used) ──────────────────────────────

export interface DbProject {
  id:                   string;
  name:                 string;
  description?:         string;
  type?:                string;
  status?:              string;
  opportunity_score?:   number;
  revenue_potential?:   number;
  priority_score?:      number;
  time_to_revenue_days?: number;
  market_analysis_id?:  string;
  url?:                 string;
  details?:             Record<string, unknown>;
}

export interface DbOpportunity {
  id:               string;
  project_id:       string;
  title:            string;
  description?:     string;
  status:           string;
  opportunity_type?: string;
  final_score:      number;
  market_score?:    number;
  revenue_score?:   number;
  competition_score?: number;
  synergy_score?:   number;
  strategic_fit?:   number;
  origin?:          string;
  rationale?:       string;
  confidence?:      string;
  risks?:           string[];
  action_steps?:    string[];
  created_at?:      string;
}

export interface DbAction {
  id:               string;
  project_id:       string;
  title:            string;
  description?:     string;
  status:           string;
  priority?:        number;
  impact_score?:    number;
  effort_score?:    number;
  roi_score?:       number;
  market_score?:    number;
  origin?:          string;
  rationale?:       string;
  created_at?:      string;
}

export interface DbKbItem {
  id:         string;
  project_id: string;
  title:      string;
  status?:    string;
  niche?:     string;
  content?:   string;
  created_at?: string;
}

export interface DbAsset {
  id:         string;
  project_id: string;
  title?:     string;
  name?:      string;
  type?:      string;
  status?:    string;
  score?:     number;
  created_at?: string;
}

export interface DbRoiMetric {
  id:           string;
  project_id:   string;
  metric_name?: string;
  metric_type?: string;
  metric_value: number;
  created_at?:  string;
}

// ── Scores ────────────────────────────────────────────────────────────────────

export interface ScoreResult {
  ecosystemScore:    number;
  opportunityScore:  number;
  marketScore:       number;
  executionScore:    number;
  strategicFit:      number;
  synergyScore:      number;
  roiScore:          number;
  momentumScore:     number;
  hasRoiData:        boolean;
  hasEnoughData:     boolean;
  recommendation:    string;
  scoreFactors:      ScoreFactors;
}

export interface ScoreFactors {
  opportunity:   string;
  market:        string;
  execution:     string;
  strategicFit:  string;
  synergy:       string;
  roi:           string;
  momentum:      string;
  ecosystem:     string;
}

// ── AI Provider ───────────────────────────────────────────────────────────────

export interface AIMessage {
  role:         'system' | 'user' | 'assistant' | 'tool';
  content:      string | null;
  tool_call_id?: string;
  tool_calls?:  AIToolCall[];
  name?:        string;
}

export interface AIToolCall {
  id:       string;
  type:     'function';
  function: { name: string; arguments: string };
}

export interface AIToolDefinition {
  type:     'function';
  function: {
    name:        string;
    description: string;
    parameters:  Record<string, unknown>;
  };
}

export interface AICompletionRequest {
  messages:     AIMessage[];
  tools?:       AIToolDefinition[];
  temperature?: number;
  max_tokens?:  number;
}

export interface AICompletionResponse {
  content:     string | null;
  tool_calls:  AIToolCall[] | null;
  model:       string;
  finish_reason: string | null;
  usage?: {
    prompt_tokens:     number;
    completion_tokens: number;
    total_tokens:      number;
  };
}

// ── Tool Registry ─────────────────────────────────────────────────────────────

export type PermissionLevel = 'read' | 'propose' | 'execute';

export interface ToolDefinition {
  name:        string;        // underscore format: action_list
  publicName:  string;        // dot format: action.list
  description: string;
  permission:  PermissionLevel;
  requiresUserConfirmation: boolean;
  parameters:  Record<string, unknown>;
}

export interface ToolExecutionContext {
  uid:           string;
  projectId:     string;
  supabase:      unknown; // SupabaseClient
  evidenceIds:   Set<string>;
  allProjectIds: Set<string>;
}

export type ToolResult =
  | { ok: true;  data: Record<string, unknown>; summary: string }
  | { ok: false; error: string; availability?: 'UNAVAILABLE' | 'UNAUTHORIZED' };

// ── Agent Orchestrator ────────────────────────────────────────────────────────

export interface AgentTurnLog {
  turn:       number;
  tool_name:  string;
  args_hash:  string;
  ok:         boolean;
  latency_ms: number;
}

export interface AgentOrchestrationResult {
  responseText:     string;
  responseId:       string;
  intent:           string;
  evidence:         Record<string, unknown>[];
  proposedAction:   Record<string, unknown> | null;
  limitations:      string[];
  confidence:       number;
  model:            string;
  promptVersion:    string;
  agentTurns:       number;
  toolsLog:         AgentTurnLog[];
  tokenUsage?:      { prompt: number; completion: number; total: number };
}

// ── Server Context (same as context-copilot) ──────────────────────────────────

export interface ServerContext {
  project:       DbProject | null;
  opportunities: DbOpportunity[];
  actions:       DbAction[];
  kb_items:      DbKbItem[];
  evidence_ids:  Set<string>;
  limitations:   string[];
  source_status?: Record<string, 'AVAILABLE' | 'EMPTY' | 'UNAVAILABLE' | 'UNAUTHORIZED' | 'NOT_LINKED'>;
}
