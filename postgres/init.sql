CREATE TABLE assets (
    tenant_id VARCHAR(64) NOT NULL,
    asset_id UUID NOT NULL,
    device_type VARCHAR(50) NOT NULL,
    os_vendor VARCHAR(100),
    os_version VARCHAR(50),
    firmware_version VARCHAR(50),
    risk_level VARCHAR(20) DEFAULT 'LOW',
    is_quarantined BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (tenant_id, asset_id)
);

CREATE TABLE network_interfaces (
    tenant_id VARCHAR(64) NOT NULL,
    interface_id UUID NOT NULL,
    asset_id UUID NOT NULL,
    mac_address VARCHAR(17) NOT NULL,
    ip_address VARCHAR(45),
    is_active BOOLEAN DEFAULT TRUE,
    last_seen_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (tenant_id, interface_id),
    FOREIGN KEY (tenant_id, asset_id)
        REFERENCES assets(tenant_id, asset_id)
        ON DELETE CASCADE
);

CREATE TABLE asset_cves (
    tenant_id VARCHAR(64) NOT NULL,
    cve_record_id SERIAL NOT NULL,
    asset_id UUID NOT NULL,
    cve_id VARCHAR(20) NOT NULL,
    cvss_score DECIMAL(3,1),
    severity VARCHAR(20) NOT NULL,
    discovered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (tenant_id, cve_record_id),
    FOREIGN KEY (tenant_id, asset_id)
        REFERENCES assets(tenant_id, asset_id)
        ON DELETE CASCADE
);

ALTER TABLE assets REPLICA IDENTITY FULL;
ALTER TABLE network_interfaces REPLICA IDENTITY FULL;
ALTER TABLE asset_cves REPLICA IDENTITY FULL;
