import os
import random
import time
import uuid
from datetime import datetime, timezone

import psycopg2
from faker import Faker

fake = Faker()

TENANTS = [
    "Acme Cyber Defense",
    "Globex Technologies",
    "Umbrella Networks",
    "Wayne Enterprises",
    "Stark Industries",
    "Cyberdyne Systems",
]

DEVICE_TYPES = ["firewall", "router", "switch", "server", "workstation", "iot-gateway"]
OS_VENDORS = ["Ubuntu", "RedHat", "Windows", "Cisco", "Fortinet", "Palo Alto"]
RISK_LEVELS = ["LOW", "MEDIUM", "HIGH"]
SEVERITIES = ["LOW", "MEDIUM", "HIGH", "CRITICAL"]


class DatabaseGenerator:
    def __init__(self):
        self.cycle_seconds = int(os.getenv("GENERATOR_CYCLE_SECONDS", "10"))
        self.min_ops = int(os.getenv("GENERATOR_MIN_OPS", "10"))
        self.max_ops = int(os.getenv("GENERATOR_MAX_OPS", "50"))

        self.conn = psycopg2.connect(
            host=os.getenv("POSTGRES_HOST", "postgres"),
            port=os.getenv("POSTGRES_PORT", "5432"),
            dbname=os.getenv("POSTGRES_DB", "cyberdemo"),
            user=os.getenv("POSTGRES_USER", "postgres"),
            password=os.getenv("POSTGRES_PASSWORD", "postgres"),
        )
        self.conn.autocommit = True

    def _choose_tenant(self):
        return random.choice(TENANTS)

    def _insert_asset(self, cur):
        tenant = self._choose_tenant()
        asset_id = uuid.uuid4()
        device_type = random.choice(DEVICE_TYPES)
        os_vendor = random.choice(OS_VENDORS)
        os_version = f"{random.randint(1, 15)}.{random.randint(0, 9)}"
        firmware_version = f"{random.randint(1, 4)}.{random.randint(0, 20)}.{random.randint(0, 50)}"

        cur.execute(
            """
            INSERT INTO assets (
                tenant_id, asset_id, device_type, os_vendor, os_version, firmware_version, risk_level, is_quarantined
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            """,
            (
                tenant,
                str(asset_id),
                device_type,
                os_vendor,
                os_version,
                firmware_version,
                "LOW",
                False,
            ),
        )
        print(f"[GENERATOR] tenant={tenant} asset={str(asset_id)[:8]} INSERT asset")

    def _update_asset(self, cur):
        cur.execute("SELECT tenant_id, asset_id, risk_level FROM assets ORDER BY random() LIMIT 1")
        row = cur.fetchone()
        if not row:
            self._insert_asset(cur)
            return

        tenant, asset_id, risk = row
        next_risk = "MEDIUM" if risk == "LOW" else "HIGH"
        next_os = f"{random.randint(1, 15)}.{random.randint(0, 9)}"
        firmware_version = f"{random.randint(1, 4)}.{random.randint(0, 20)}.{random.randint(0, 50)}"
        is_quarantined = next_risk == "HIGH" and random.random() < 0.4

        cur.execute(
            """
            UPDATE assets
            SET os_version = %s,
                firmware_version = %s,
                risk_level = %s,
                is_quarantined = %s,
                updated_at = CURRENT_TIMESTAMP
            WHERE tenant_id = %s AND asset_id = %s
            """,
            (next_os, firmware_version, next_risk, is_quarantined, tenant, str(asset_id)),
        )
        print(f"[GENERATOR] tenant={tenant} asset={str(asset_id)[:8]} UPDATE risk_level {next_risk}")

    def _insert_network_interface(self, cur):
        cur.execute("SELECT tenant_id, asset_id FROM assets ORDER BY random() LIMIT 1")
        row = cur.fetchone()
        if not row:
            self._insert_asset(cur)
            cur.execute("SELECT tenant_id, asset_id FROM assets ORDER BY random() LIMIT 1")
            row = cur.fetchone()

        tenant, asset_id = row
        interface_id = uuid.uuid4()
        mac_address = fake.mac_address()
        ip_address = fake.ipv4_private()

        cur.execute(
            """
            INSERT INTO network_interfaces (
                tenant_id, interface_id, asset_id, mac_address, ip_address, is_active
            ) VALUES (%s, %s, %s, %s, %s, %s)
            """,
            (tenant, str(interface_id), str(asset_id), mac_address, ip_address, True),
        )
        print(f"[GENERATOR] tenant={tenant} asset={str(asset_id)[:8]} INSERT network_interface")

    def _update_network_interface(self, cur):
        cur.execute(
            "SELECT tenant_id, interface_id FROM network_interfaces ORDER BY random() LIMIT 1"
        )
        row = cur.fetchone()
        if not row:
            self._insert_network_interface(cur)
            return

        tenant, interface_id = row
        is_active = random.random() > 0.2
        ip_address = fake.ipv4_private()

        cur.execute(
            """
            UPDATE network_interfaces
            SET is_active = %s,
                ip_address = %s,
                last_seen_at = CURRENT_TIMESTAMP
            WHERE tenant_id = %s AND interface_id = %s
            """,
            (is_active, ip_address, tenant, str(interface_id)),
        )
        state = "active" if is_active else "inactive"
        print(f"[GENERATOR] tenant={tenant} interface={str(interface_id)[:8]} UPDATE {state}")

    def _insert_cve(self, cur):
        cur.execute("SELECT tenant_id, asset_id FROM assets ORDER BY random() LIMIT 1")
        row = cur.fetchone()
        if not row:
            self._insert_asset(cur)
            cur.execute("SELECT tenant_id, asset_id FROM assets ORDER BY random() LIMIT 1")
            row = cur.fetchone()

        tenant, asset_id = row
        cve_id = f"CVE-2026-{random.randint(10000, 99999)}"
        cvss = round(random.uniform(3.0, 10.0), 1)
        severity = (
            "CRITICAL" if cvss >= 9.0 else "HIGH" if cvss >= 7.0 else "MEDIUM" if cvss >= 4.0 else "LOW"
        )

        cur.execute(
            """
            INSERT INTO asset_cves (
                tenant_id, asset_id, cve_id, cvss_score, severity
            ) VALUES (%s, %s, %s, %s, %s)
            """,
            (tenant, str(asset_id), cve_id, cvss, severity),
        )
        print(f"[GENERATOR] tenant={tenant} asset={str(asset_id)[:8]} INSERT {cve_id}")

    def _update_cve(self, cur):
        cur.execute(
            "SELECT tenant_id, cve_record_id, cve_id FROM asset_cves ORDER BY random() LIMIT 1"
        )
        row = cur.fetchone()
        if not row:
            self._insert_cve(cur)
            return

        tenant, cve_record_id, cve_id = row
        cvss = round(random.uniform(3.0, 10.0), 1)
        severity = random.choice(SEVERITIES)

        cur.execute(
            """
            UPDATE asset_cves
            SET cvss_score = %s,
                severity = %s,
                discovered_at = CURRENT_TIMESTAMP
            WHERE tenant_id = %s AND cve_record_id = %s
            """,
            (cvss, severity, tenant, cve_record_id),
        )
        print(f"[GENERATOR] tenant={tenant} cve={cve_id} UPDATE score={cvss}")

    def _one_operation(self, cur):
        op = random.choice(
            [
                self._insert_asset,
                self._update_asset,
                self._insert_network_interface,
                self._update_network_interface,
                self._insert_cve,
                self._update_cve,
            ]
        )
        op(cur)

    def run(self):
        print("[GENERATOR] started")
        while True:
            started = datetime.now(timezone.utc).isoformat()
            ops = random.randint(self.min_ops, self.max_ops)
            with self.conn.cursor() as cur:
                for _ in range(ops):
                    self._one_operation(cur)
            print(f"[GENERATOR] cycle_start={started} ops={ops} completed")
            time.sleep(self.cycle_seconds)


if __name__ == "__main__":
    DatabaseGenerator().run()
