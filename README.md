# Chain Secretary: BIP-322 Vote Verifier

Welcome to the **Chain Secretary** recruitment task for PCLUB IITK! 

In decentralized communities, governance relies on cryptographic proofs. Your task is to build a **BIP-322 vote verifier and tally engine**. Given a snapshot of members, a proposal, and a set of cryptographically signed votes, your software will act as the "Secretary": verifying the cryptographic signatures, filtering out bad actors, applying governance rules, and calculating the final pass/fail result.

---

##  Objective

You must implement a CLI-based evaluation engine that parses a JSON fixture file, mathematically verifies each voter's signature against the **BIP-322** standard, applies strict voting policies, and outputs a deterministic tally report.

###  Strict Restrictions
To ensure fair grading, **YOU ARE STRICTLY NOT ALLOWED TO EDIT** the following files and directories:
- `fixtures/` (Contains all the test cases)
- `grader/` (Contains the evaluation script)
- `expected_outputs/` (The exact JSONs your program must produce).

You must only edit the files within your chosen language's directory (e.g., `rust/`, `python/`) and update `cli.sh` to correctly invoke your code. You must also create `demo.md` at the root of the repository.

---

##  The Rules of Voting

Your engine must process the `votes` array in the fixture and strictly apply the following pipeline. **The order of these checks is crucial** to match the expected deterministic output.

1. **Authenticity (`INVALID_SIGNATURE`)**: 
   - Every vote must be signed using the **BIP-322 Generic Signed Message Format**.
   - Specifically, you will encounter `smp` (Simple) signatures. These are base64-encoded witness stacks.
   - You must verify that the given signature mathematically proves the voter owns the `address` and signed the exact `message` string.
2. **Eligibility (`UNKNOWN_MEMBER`)**:
   - The voter's `address` must exist in the authoritative `members` snapshot.
3. **Replay Protection & Duplicates**:
   - A user might submit multiple votes. Group all validly-signed votes by address.
   - **Rule**: Only the vote with the **highest valid nonce** is counted.
   - **Errors**: 
     - Any vote with a strictly lower nonce than the maximum submitted by that user should be marked as `REPLAY_ATTEMPT`.
     - If there are multiple votes with the *same* highest nonce, pick the first one chronologically and mark the others as `DUPLICATE_VOTE`.
4. **Choice Set (`INVALID_CHOICE`)**:
   - The choice must be exactly `"yes"` or `"no"`. Any other choice (e.g., "maybe") is invalid.
5. **Vote Window (`OUTSIDE_VOTING_WINDOW`)**:
   - The vote's `timestamp` must fall within the proposal's window: `start_ts <= timestamp <= end_ts`.

### Tallying & Quorum
After filtering votes into `counted_votes` and `rejected_votes`:
- **Basis Points (bps)**: Policies are defined in basis points (1 bps = 0.01%). So, `5000 bps` = `50.00%`.
- **Quorum**: The proposal meets quorum if:
  `(participating_power * 10000) / total_snapshot_power >= policy.quorum_bps`
  *(If quorum is not reached, emit a `LOW_PARTICIPATION` warning).*
- **Pass Threshold**: A proposal passes if quorum is reached AND:
  `(yes_power * 10000) / participating_power >= policy.pass_threshold_bps`

---

##  Required Interface

The grader will execute your code via the wrapper script `cli.sh`. 

```bash
./cli.sh fixtures/<fixture_name>.json
```

**Responsibilities of `cli.sh` & your app**:
1. Read the input JSON file.
2. Ensure the `out/` directory exists.
3. Write exactly one JSON output file to `out/<fixture_name>.json`.
4. Exit with code `0` on success, or `1` on a fatal processing error/invalid fixture.
5. Do **not** print anything to `stdout` except standard logs (use `stderr` for logs if needed, the grader ignores it).

---

##  Output Format & Determinism

Your output must perfectly match the structure found in `grader/expected_outputs/`. 

```json
{
  "ok": true,
  "proposal_id": "prop-001",
  "network": "mainnet",
  "totals": {
    "snapshot_power": 1000,
    "participating_power": 740,
    "yes_power": 520,
    "no_power": 220
  },
  "quorum_reached": true,
  "passed": true,
  "counted_votes": 12,
  "rejected_votes": [
    { "address": "bc1q...", "code": "INVALID_SIGNATURE" }
  ],
  "warnings": [
    { "code": "LOW_PARTICIPATION" }
  ]
}
```

 **CRITICAL: Determinism** 
To ensure the automated grader passes your output, all JSON arrays (`rejected_votes`, `warnings`) **must be sorted alphabetically**.
- Sort `rejected_votes` primarily by `address` (A-Z), and secondarily by `code` (A-Z).
- Sort `warnings` by `code` (A-Z).

---

## Resources & Libraries

Implementing BIP-322 from scratch requires understanding Bitcoin transactions (virtual `to_spend` and `to_sign` transactions) and witness stacks. You are highly encouraged to use established libraries.

**Recommended Libraries:**
*   **Rust**: `bitcoin`, `secp256k1`, `bip322` or `bip322-rs`. *(Hint: If doing this manually in Rust, remember `smp` signatures are Base64 encoded witness stacks, and you must verify the P2WPKH signature).*
*   **Python**: `python-bitcointx`, `bitcoinlib`.

**Reading Material:**
*   [BIP-322 Specification](https://github.com/bitcoin/bips/blob/master/bip-0322.mediawiki)

---

##  Deliverables & Acceptance Criteria

1. **Codebase**: Fully functional evaluator cleanly integrated with `cli.sh`.
2. **Tests**: At least 15 unit tests covering signature verification, duplicate handling, bounds, and quorum rules. Place them in your language's standard test folder.
3. **Demo Video (`demo.md`)**: A markdown file at the root of the repository containing a single link to a YouTube, Loom, or Google Drive video (unlisted/public).
   - **Under 3 minutes**.
   - Show the CLI running a fixture successfully.
   - Explain your approach to BIP-322 signature verification.
   - Explain the tallying math.
   - Show one failure/edge case.

### How to test locally
You can run the official grading script to see your score:
```bash
./grader/grade.sh
```
*Note for Windows users: You must run this command in **Git Bash** (or WSL) and ensure you have `jq` installed on your system, as the grader uses `jq` to parse and compare JSON files deterministically.*

Good luck!!
