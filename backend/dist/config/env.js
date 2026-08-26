import 'dotenv/config';
export const env = {
    port: Number(process.env.PORT ?? 8081),
    // Production Supabase Postgres as default so cloud deploys always
    // connect; override locally with DATABASE_URL when needed.
    databaseUrl: process.env.DATABASE_URL ??
        'postgresql://postgres.osnhftjsormgodsabdbn:CSE327%40TradeLink@aws-0-ap-northeast-1.pooler.supabase.com:6543/postgres',
    jwtSecret: process.env.JWT_SECRET ?? '',
    authProvider: process.env.AUTH_PROVIDER ?? 'supabase',
    // Demo (X-User-Id header) auth is the default until Supabase-JWT
    // login ships in the Flutter client. ONLY an explicit DEMO_MODE=false
    // disables it — empty/unset values stay in demo mode.
    demoMode: (process.env.DEMO_MODE?.trim().toLowerCase() ?? 'true') !== 'false',
    corsOrigins: (process.env.CORS_ORIGINS ?? 'http://localhost:8080')
        .split(',')
        .map((o) => o.trim()),
};
//# sourceMappingURL=env.js.map