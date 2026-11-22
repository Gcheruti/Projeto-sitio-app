/// Preencha com o projeto Supabase do Sítio.
/// Alternativa: passar em runtime:
/// flutter run -d chrome --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://cucabiqhtwqlxujgflnq.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN1Y2FiaXFodHdxbHh1amdmbG5xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI5MjY2ODEsImV4cCI6MjEwODUwMjY4MX0.iWj6AjQewc3GT9hiSJvDElIvklR9_mUxe1weHdBmzx4',
  );
}