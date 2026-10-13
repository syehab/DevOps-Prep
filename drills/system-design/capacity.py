#!/usr/bin/env python3
"""ShopSphere interview capacity numbers. Run: python3 capacity.py"""

from __future__ import annotations

MONTH_MINUTES = 30 * 24 * 60  # 43200


def error_budget_minutes(slo: float, days: int = 30) -> float:
    """Unused error budget in minutes. slo is 0.999 for 99.9%."""
    return days * 24 * 60 * (1.0 - slo)


def inflight(rps: float, service_s: float) -> float:
    """Little's law: L = λW. rps * service time in seconds."""
    return rps * service_s


def orders_rps(orders_per_hour: float) -> float:
    return orders_per_hour / 3600.0


def object_store_gb(objects: int, bytes_each: int) -> float:
    return objects * bytes_each / 1e9


def pool_total(pods: int, connections_per_pod: int) -> int:
    return pods * connections_per_pod


def main() -> None:
    checks = {
        "budget_99_9_30d_min": error_budget_minutes(0.999),
        "budget_99_95_30d_min": error_budget_minutes(0.9995),
        "inflight_500rps_50ms": inflight(500, 0.050),
        "inflight_2000rps_20ms": inflight(2000, 0.020),
        "orders_10k_per_hour_rps": orders_rps(10_000),
        "objects_2m_x_200kib_gb": object_store_gb(2_000_000, 200_000),
        "db_conns_12x20": pool_total(12, 20),
        "burn_14_4_x_0_001": 14.4 * 0.001,
    }
    for key, value in checks.items():
        print(f"{key}={value}")


if __name__ == "__main__":
    main()
