import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'delete-account edge function exists and uses service role only server-side',
    () {
      final file = File('supabase/functions/delete-account/index.ts');

      expect(file.existsSync(), isTrue);
      final source = file.readAsStringSync();

      expect(source, contains('SUPABASE_SERVICE_ROLE_KEY'));
      expect(source, contains('auth.getUser'));
      expect(source, contains("req.method !== 'POST'"));
      expect(source, contains("authorization.startsWith('Bearer ')"));
      expect(source, contains('function_unavailable'));
      expect(source, contains('group_ownership_blocked'));
      expect(source, contains("rpc('delete_account_data'"));
      expect(source, contains("case 'super_admin_forbidden':"));
      expect(source, contains("case 'group_ownership_blocked':"));
      expect(source, contains('admin.deleteUser'));
      expect(source, contains('appleRevoked: false'));
      expect(source, isNot(contains(".from('ibadat_groups').delete()")));
      expect(
        source,
        isNot(contains(".from('ibadat_periods').delete().eq('created_by'")),
      );
      expect(
        source.indexOf("rpc('delete_account_data'"),
        lessThan(source.indexOf('admin.deleteUser')),
      );
    },
  );

  test('delete-account edge function responds to CORS preflight', () {
    final file = File('supabase/functions/delete-account/index.ts');

    expect(file.existsSync(), isTrue);
    final source = file.readAsStringSync();

    expect(source, contains('Access-Control-Allow-Origin'));
    expect(source, contains("req.method === 'OPTIONS'"));
    expect(source, contains('Access-Control-Allow-Methods'));
    expect(source, contains('POST, OPTIONS'));
  });

  test('delete_account_data migration keeps cleanup transactional and scoped', () {
    final file =
        File('db/migrations/2026-08-05_delete_account_data_rpc.sql');

    expect(file.existsSync(), isTrue);
    final sql = file.readAsStringSync().toLowerCase();

    expect(sql, contains('create or replace function delete_account_data'));
    expect(sql, contains('security definer'));
    expect(sql, contains("v_role = 'super_admin'"));
    expect(sql, contains('where admin_id = p_user_id'));
    expect(sql, contains('delete from ibadat_member_settings'));
    expect(sql, contains('delete from ibadat_payments'));
    expect(sql, contains('is_personal = true'));
    expect(sql, contains('update ibadat_periods as period'));
    expect(sql, contains('set created_by = groups.admin_id'));
    expect(sql, contains('period.group_id = groups.id'));
    expect(sql, contains('update ibadat_profiles as profile'));
    expect(sql, contains('set created_by_admin_id = groups.admin_id'));
    expect(sql, contains('set created_by_admin_id = null'));
    expect(sql, contains('update ibadat_payments'));
    expect(sql, contains('set created_by = null'));
    expect(sql, contains('delete from group_metrics'));
    expect(sql, contains('where admin_id = p_user_id'));
    expect(sql, contains('update ibadat_invite_codes'));
    expect(sql, contains('set created_by = null'));
    expect(sql, contains('set financier_id = null'));
    expect(sql, isNot(contains('delete from ibadat_invite_codes')));
    expect(sql, isNot(contains('delete from ibadat_groups')));
    expect(
      sql.indexOf('delete from report_metric_values'),
      lessThan(sql.indexOf('delete from ibadat_reports')),
    );
    expect(
      sql.indexOf('update ibadat_periods as period'),
      lessThan(sql.indexOf('delete from ibadat_profiles')),
    );
  });
}
