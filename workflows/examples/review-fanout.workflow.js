export const meta = {
  name: 'review-fanout',
  description: 'Fan out cheap finder agents across review dimensions, dedupe their findings, then uphold each one only if it survives adversarial refutation by a majority of expensive skeptic agents. Returns the survivors.',
  phases: [
    { title: 'Find', detail: 'one cheap finder agent per review dimension, in parallel' },
    { title: 'Verify', detail: 'skeptic agents try to refute each unique finding; majority vote decides' },
  ],
}

// Each finder reviews ONE dimension and returns a flat list of findings.
const FINDER_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['findings'],
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['title', 'severity', 'location', 'rationale'],
        properties: {
          title: { type: 'string' },
          severity: { enum: ['low', 'medium', 'high'] },
          location: { type: 'string' },
          rationale: { type: 'string' },
        },
      },
    },
  },
}

// A skeptic is asked to REFUTE a finding. `refuted: true` means the skeptic
// showed the finding is wrong or not a real problem (a vote against it).
const SKEPTIC_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['refuted', 'rationale'],
  properties: {
    refuted: { type: 'boolean' },
    rationale: { type: 'string' },
  },
}

// Default review dimensions. Each becomes one finder agent. Callers may
// override via args.dimensions.
const DEFAULT_DIMENSIONS = [
  'correctness',
  'security',
  'error-handling',
  'performance',
  'readability',
]

// Number of independent skeptics per finding, and the number of them that
// must FAIL to refute for the finding to be upheld (a majority of three).
const SKEPTICS_PER_FINDING = 3
const UPHOLD_THRESHOLD = 2

function normalize(title) {
  return title.toLowerCase().replace(/[^\p{L}\p{N}]+/gu, ' ').trim()
}

// Merge findings from every finder into one list, collapsing near-duplicates
// that different dimensions surfaced. Dedup key is the normalized title; the
// first occurrence wins and the highest severity seen is kept. Order is the
// order of first appearance, so the result is deterministic (no randomness).
function dedupe(perDimension) {
  const rank = { low: 0, medium: 1, high: 2 }
  const byKey = new Map()
  const order = []
  for (const group of perDimension) {
    for (const f of group.findings) {
      const key = normalize(f.title)
      // A key of "" means the title had no letters or digits at all (e.g. an
      // empty string, or punctuation-only like "!!!"), not a non-Latin title:
      // normalize() keeps any Unicode letter or number, so CJK/Cyrillic/Greek
      // titles produce a real key here. Log instead of silently dropping, so
      // a schema-valid finding with a degenerate title still leaves a trace.
      if (!key) {
        log(`Skipping a finding with no usable title (dimension: ${group.dimension}, raw title: ${JSON.stringify(f.title)}).`)
        continue
      }
      if (!byKey.has(key)) {
        byKey.set(key, { ...f, dimensions: [group.dimension] })
        order.push(key)
      } else {
        const kept = byKey.get(key)
        if (rank[f.severity] > rank[kept.severity]) kept.severity = f.severity
        if (!kept.dimensions.includes(group.dimension)) kept.dimensions.push(group.dimension)
      }
    }
  }
  return order.map((key, i) => ({ id: `f${i + 1}`, ...byKey.get(key) }))
}

function finderPrompt(target, dimension) {
  return `You are a code reviewer. Review the target below for issues in ONE dimension only: ${dimension}.

Target to review:
${target}

Report only real ${dimension} problems you can point to. For each, give a short title, a severity (low, medium, or high), the location (file, symbol, or line region), and a one or two sentence rationale. Do not invent problems to fill a quota; if the dimension is clean, return an empty list. Read only; do not edit anything.`
}

function skepticPrompt(target, finding) {
  return `You are a skeptical senior reviewer. Another agent raised the finding below. Your job is to REFUTE it: argue, from the actual target, that it is wrong, already handled, out of scope, or not a real problem.

Target under review:
${target}

The finding to attack:
- title: ${finding.title}
- severity: ${finding.severity}
- location: ${finding.location}
- rationale: ${finding.rationale}

Decide honestly. Set "refuted" to true only if you can actually show the finding does not hold; set it to false if the finding survives your scrutiny. Give a one or two sentence rationale for your call. Read only; do not edit anything.`
}

phase('Find')
const input = typeof args === 'string' ? JSON.parse(args) : (args || {})
const target = input.target
if (!target) {
  log('No target supplied (expected args.target); nothing to review.')
  return { findings: [], upheld: [] }
}
const dimensions = Array.isArray(input.dimensions) && input.dimensions.length
  ? input.dimensions
  : DEFAULT_DIMENSIONS

log(`Finding across ${dimensions.length} dimension(s) with cheap agents: ${dimensions.join(', ')}`)

const perDimension = await parallel(
  dimensions.map((dimension) => () =>
    agent(finderPrompt(target, dimension), {
      model: 'haiku',
      label: `find:${dimension}`,
      phase: 'Find',
      schema: FINDER_SCHEMA,
    }).then((r) => ({ dimension, findings: (r && r.findings) || [] }))
  )
)

const candidates = dedupe(perDimension)
log(`Collected ${candidates.length} unique finding(s) after dedupe.`)
if (candidates.length === 0) {
  return { findings: [], upheld: [] }
}

phase('Verify')
log(`Verifying ${candidates.length} finding(s): ${SKEPTICS_PER_FINDING} skeptics each, uphold at >= ${UPHOLD_THRESHOLD} that cannot refute.`)

// For every finding, run SKEPTICS_PER_FINDING independent refutation attempts
// on the expensive tier. All skeptic calls across all findings run in one
// parallel batch; results are regrouped by finding afterward.
const jobs = []
for (const finding of candidates) {
  for (let k = 0; k < SKEPTICS_PER_FINDING; k++) {
    jobs.push({ finding, k })
  }
}

const votes = await parallel(
  jobs.map((job) => () =>
    agent(skepticPrompt(target, job.finding), {
      model: 'opus',
      label: `verify:${job.finding.id}:${job.k + 1}`,
      phase: 'Verify',
      schema: SKEPTIC_SCHEMA,
    }).then((r) => {
      // A falsy or non-conforming result (transient error, schema miss) is
      // NOT a vote that the finding survived scrutiny; it is a vote nobody
      // cast. Track it as its own outcome so it can neither uphold nor
      // refute the finding.
      const valid = !!r && typeof r.refuted === 'boolean'
      const verdict = !valid ? 'invalid' : r.refuted ? 'refuted' : 'upheld'
      return { id: job.finding.id, verdict, rationale: r && r.rationale }
    })
  )
)

const tally = new Map()
for (const c of candidates) tally.set(c.id, { upheld: 0, refuted: 0, invalid: 0 })
for (const v of votes) {
  tally.get(v.id)[v.verdict]++
}

const upheld = []
for (const c of candidates) {
  const t = tally.get(c.id)
  const effectiveSkeptics = SKEPTICS_PER_FINDING - t.invalid
  if (t.invalid > 0) {
    log(`Finding ${c.id} ("${c.title}"): ${t.invalid} of ${SKEPTICS_PER_FINDING} skeptic call(s) came back invalid; only ${effectiveSkeptics} reached a real verdict.`)
  }
  // Explicit tie-break: if too many skeptics failed to reach a verdict, the
  // remaining ones can no longer mathematically clear UPHOLD_THRESHOLD, and
  // the finding is treated as not upheld rather than as refuted (it was
  // never actually attacked enough times to say either).
  if (effectiveSkeptics < UPHOLD_THRESHOLD) {
    log(`Finding ${c.id} cannot be upheld: insufficient scrutiny (${effectiveSkeptics}/${SKEPTICS_PER_FINDING} skeptics reached a verdict, ${UPHOLD_THRESHOLD} needed).`)
    continue
  }
  if (t.upheld >= UPHOLD_THRESHOLD) {
    upheld.push({ ...c, upheldVotes: t.upheld, skeptics: SKEPTICS_PER_FINDING, effectiveSkeptics })
  }
}

log(`Upheld ${upheld.length} of ${candidates.length} finding(s) after adversarial verification.`)
return { findings: candidates, upheld }
