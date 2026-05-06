# Phase 3 — Failover drill

Documented run of the Pilot Light DR pattern: simulate a primary-region failure and time the recovery.

## Procedure

```bash
cd infra/03-dr-pilot-light
bash failover-drill.sh
```

The script:

1. Confirms primary serves 200 from `sre-alb-1428213202.us-west-2.elb.amazonaws.com`
2. Scales primary `ecs:UpdateService desired-count=0` (simulates regional failure)
3. Scales DR `ecs:UpdateService desired-count=2` in `us-east-1`
4. Polls DR ALB until 200, captures recovery time
5. Reverses (primary back to 1, DR back to 0)

## Expected timing

| Phase | Typical duration |
|---|---|
| Scale-down command (primary → 0) | <2 sec API call |
| Existing primary tasks drain | ~30 sec deregistration_delay |
| Scale-up command (DR → 2) | <2 sec API call |
| Fargate task cold start | 30–60 sec (image pull is fast — image already in DR ECR via cross-region replication) |
| ALB target health check passes | 60 sec (2 healthy checks at 30s interval) |
| **Total time-to-recovery** | **~2 minutes** |

## Capture for portfolio

Run the drill and capture the terminal as `screenshots/10-failover-drill.png`. The output's color-coded steps make it visually compelling. Key timestamps to highlight:

- `Primary scaled to 0 at HH:MM:SS UTC`
- `DR healthy after Ns.`

## Why Pilot Light vs alternatives

| Pattern | Standby cost (this project) | RTO | RPO |
|---|---|---|---|
| Backup/Restore | ~$0/mo | hours | hours |
| **Pilot Light** | **~$17/mo** | **~2 min** | **~0 min for ECR; ~10 sec for DDB Global** |
| Warm Standby | ~$25/mo (1 task running both regions) | ~30 sec | same as Pilot Light |
| Multi-Site Active/Active | ~$50/mo (2 tasks both regions, full traffic split) | 0 | 0 |

For a $120 budget over 8–10 weeks, Pilot Light hits the right point on the cost/RTO curve. Production-grade systems with strict SLAs would justify Warm Standby or Active/Active.

## Limitations of this drill

- **No data plane traffic during failover.** Real failover would also test database failover, cache warming, queue draining. We only test compute.
- **No DNS swap.** We hit the DR ALB directly instead of via Route 53 because we don't currently own the failover record (no Route 53 hosted zone yet). Production drill would include the DNS change in the timing.
- **Single-region human operator.** A real test would also verify that the operator's tools (kubectl, AWS CLI, dashboards) still work when the primary region is "down."

## What the screenshot proves

That the SAA exam concept of Pilot Light isn't just a diagram — it's a real, working pattern with measurable RTO. Pair this with the architecture-dr-pilot-light.png diagram in the README and the migration story makes itself.
