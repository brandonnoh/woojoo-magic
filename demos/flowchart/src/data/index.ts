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

export const VIEWBOX = { width: 3360, height: 1300 } as const;
