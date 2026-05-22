import type { FlowGraph } from "../types/graph";
import { ENTRY_NODES } from "./entry";
import { COMMAND_NODES } from "./commands";
import { SKILL_NODES } from "./skills";
import { AGENT_NODES } from "./agents";
import { HOOK_NODES } from "./hooks";
import { EDGES } from "./edges";

export const GRAPH: FlowGraph = {
  nodes: [...ENTRY_NODES, ...COMMAND_NODES, ...SKILL_NODES, ...AGENT_NODES, ...HOOK_NODES],
  edges: EDGES,
};

export const VIEWBOX = { width: 2080, height: 1200 } as const;
