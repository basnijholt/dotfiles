# PC Idle Power Cost Estimate

**Location:** Kirkland, WA (Puget Sound Energy)
**Date:** December 2025

## Hardware Summary

| Component | Specs | Idle Power |
|-----------|-------|------------|
| CPU | AMD Ryzen 9 3900X (12-core) | ~20-30W |
| GPUs | 2× NVIDIA RTX 3090 (270W power limit) | **63W measured** (39W + 24W) |
| RAM | 64GB DDR4 | ~8-10W |
| Storage | 2× NVMe (1.9TB + 3.6TB) | ~3-5W |
| Motherboard/fans/misc | X570 chipset | ~15-25W |

**Estimated Total Idle Power: ~100-140W** (realistic average: **~120W**)

## Cost Calculation

### Electricity Rate

Puget Sound Energy residential rate (Dec 2025): **~$0.17/kWh**

- Base rate ~$0.15/kWh + 12% increase (Jan 2025) + 4.3% increase (Aug 2025)
- Source: [WA UTC Rate Approval](https://www.utc.wa.gov/news/2025/state-regulators-approve-new-rates-pse)

### Running 24/7 Idle

| Period | Hours | kWh | Cost |
|--------|-------|-----|------|
| Daily | 24 | 2.88 | **$0.49** |
| Monthly | 730 | 87.6 | **$14.89** |
| Yearly | 8,760 | 1,051 | **$179** |

## Power Saving Tips

- **Disconnect display from second GPU**: Saves ~15-20W idle
- **Enable GPU power saving modes**: Minor savings
- **Use suspend/hibernate**: Drops to ~5-10W
- **Full shutdown**: ~1-3W (standby power)

## Notes

- RTX 3090s draw significant idle power (~25-35W each) especially with displays connected
- The 270W power limit configured in `nvidia-undervolt.nix` only affects load, not idle
- Actual idle may vary based on running services, wake timers, and peripheral devices
