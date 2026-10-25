-- Migration 000014: Create Security Device Tokens for FCM Fallback Push Notification

CREATE TABLE IF NOT EXISTS security_device_tokens (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id VARCHAR(100) NOT NULL,
    device_token TEXT NOT NULL,
    platform VARCHAR(20) NOT NULL DEFAULT 'android' CHECK (platform IN ('android', 'ios', 'web')),
    is_active BOOLEAN NOT NULL DEFAULT true,
    last_seen_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_security_user_device UNIQUE (user_id, device_id)
);

CREATE INDEX IF NOT EXISTS idx_sec_device_tokens_user_active ON security_device_tokens(user_id, is_active);
CREATE INDEX IF NOT EXISTS idx_sec_device_tokens_token ON security_device_tokens(device_token);
