-- Pré-popula uma chave de API para uso no ambiente local.
-- Chave:  tm_key_local_dev_service_key_00000000
-- Hash:   SHA-256 da chave acima (usada pelo evaluation-service via SERVICE_API_KEY)
INSERT INTO api_keys (name, key_hash, is_active)
VALUES (
    'local-dev-service-key',
    '23dbee47b4a9577f203c40152e01e012d971df44e6f9cfc0fcf0ab2b267bc7bc',
    true
)
ON CONFLICT (key_hash) DO NOTHING;
