---
name: n8n
description: Documents an n8n workflow via n8n-mcp — writes a 4-5 sentence Polish explanation into every node's real Settings > Notes field, forces every OpenRouter Chat Model onto the free "openai/gpt-oss-120b" model (even overriding one that was already explicitly set to something else — paid OpenRouter models don't work on this user's account), and adds one canvas-level Sticky Note summarizing the workflow. Use ONLY when the user explicitly invokes this skill by its exact name/command (e.g. "/n8n", "użyj skilla n8n"). The word "n8n" alone in a message is NOT an invocation — this repo, every workflow, and most messages here are about n8n, so do not treat ordinary mentions, questions, or unrelated n8n-mcp work as a trigger. Do NOT trigger this proactively or automatically either — not right after building or editing a workflow, not because documentation would obviously help. The user deliberately opted out of automatic triggering; wait for an explicit, unambiguous call every time.
---

# n8n (skill)

> **Tylko użytkownik wywołuje ten skill, wprost i w bieżącej wiadomości.** Jeśli
> trafiłeś tutaj z jakiegokolwiek innego powodu — skojarzenie ze słowem "n8n",
> właśnie zbudowany/edytowany workflow, wzmianka o notatkach/dokumentacji, domysł że
> "to by się przydało" — **zatrzymaj się i nic nie rób**. To nie jest automatyczna
> dokumentacja ani coś, co odpalasz z własnej inicjatywy. Wróć do rozmowy i kontynuuj
> normalnie, bez wzmianki o tym skillu.

Documents one n8n workflow: per-node explanations in the real `Notes` field, a sane
default chat model when one is missing, and a short canvas summary.

## Which workflow

If the user named a workflow (by name, id, or "the one we just built"), use that.
Otherwise ask which workflow before doing anything — never guess.

Always start with `mcp__n8n-mcp__get_workflow_details` on the target workflow. You need
its full node list (`id`, `type`, `typeVersion`, `parameters`, `position`) and the full
`connections` object before changing anything — the rest of this skill depends on that
snapshot.

## Step 1 — Real per-node Notes

Goal: every non-Sticky-Note node gets 4-5 sentences of Polish explanation in its actual
`Notes` field — the one under the node's **Settings** tab, which is a top-level property
on the node object (`node.notes`, sibling to `type`/`position`/`parameters`), not
something inside `parameters`.

**Why you can't just set it directly:** `update_workflow`'s `setNodeParameter` and
`updateNodeParameters` operations always write inside `node.parameters`, no matter what
JSON Pointer path you give them — `path: "/notes"` silently creates a bogus
`parameters.notes` field instead of touching the real one. This was confirmed
empirically: it produces no error, no validation warning, and the note simply doesn't
show up where the user expects it. The only operation whose schema exposes a top-level
`notes` field is `addNode`. So setting Notes on an *existing* node means recreating it:

1. From the snapshot you already have, for each real node write 4-5 sentences in Polish:
   what the node is, and — more usefully — what role it plays in *this* workflow
   specifically (what feeds it, what it decides, what downstream node depends on it).
   Generic node-type descriptions are worth little; the point is to explain this
   instance's logic, the way a good inline comment explains a specific call site.
2. Build ONE atomic `update_workflow` call containing, for every real node: a
   `removeNode` op for it, then an `addNode` op that recreates it with the *exact same*
   `id`, `type`, `typeVersion`, `parameters`, and `position` as the snapshot, plus the
   new `notes` string.
3. `removeNode` strips every connection touching that node, as both source and target,
   from the workflow — nothing is preserved automatically. In the same atomic call, add
   `addConnection` ops that reconstruct every connection that existed in the snapshot's
   `connections` object (source, target, `connectionType`, `sourceIndex`/`targetIndex`).
   Read the snapshot's connections object carefully: it's keyed by source node name, and
   each entry can have multiple connection types (`main`, `ai_tool`, `ai_languageModel`,
   `ai_memory`, ...) — restore all of them, not just `main`.

Do this for every node in one `operations` array so it applies atomically — if anything
is wrong, nothing gets half-saved.

Skip Sticky Note nodes (`n8n-nodes-base.stickyNote`) — they're already documentation and
don't have a separate Notes field worth filling.

## Step 2 — Force the free OpenRouter model, every time

While rebuilding nodes in Step 1, check any node of type
`@n8n/n8n-nodes-langchain.lmChatOpenRouter` ("OpenRouter Chat Model"). Its `model`
parameter is a plain string (not a resource-locator object). Always set it to
`"openai/gpt-oss-120b"` when you recreate the node via `addNode` — regardless of whether
the field is missing, empty, or already holds a different, explicitly-set model.

**Paid OpenRouter models don't work on this user's account.** Do not treat an existing
non-free model as a deliberate choice to be preserved, even if it looks reasoned (e.g.
a stronger paid model picked because a course or task called for better reasoning
quality). It will fail at runtime regardless of the reasoning behind it — the only model
confirmed to actually run in this n8n instance is the free `openai/gpt-oss-120b` (see
workflow "009 — Asystent portfela inwestycyjnego w czacie"). Overwrite it every time and
mention in your report that you did, so the user knows a paid model was swapped out.

## Step 3 — One canvas-level Sticky Note

Separately from the per-node notes, add exactly one `n8n-nodes-base.stickyNote` node via
`addNode` (don't touch existing nodes for this). This is the one piece of documentation
that intentionally lives outside any node, visible on the canvas without opening
anything. Position it clear of every other node — check the snapshot's positions and
place it below the lowest one, wide enough (e.g. 450-600px) not to force wrapping.

Content: max 5 sentences in Polish, markdown, roughly:
- what this workflow does / what problem it solves for the user
- how to actually run or test it (e.g. "otwórz panel czatu i napisz X", any credential
  that must be configured first for it to work)

## Reporting back

Report in Polish, in short bullets, conclusion first, no closing question unless you
hit something you genuinely couldn't do without the user's input (e.g. workflow not
found, ambiguous target):

- which nodes got notes (just confirm "wszystkie N nodów", no need to restate content)
- whether an OpenRouter model was set/corrected to the free default, and what it was before (if it changed)
- the workflow's `url` (from the `get_workflow_details`/`update_workflow` response)
