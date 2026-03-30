import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ibadat_payment.dart';

class PaymentRepository {
  final SupabaseClient _client;

  PaymentRepository(this._client);

  Future<List<IbadatPayment>> getPaymentsByGroup(String groupId) async {
    final data = await _client
        .from('ibadat_payments')
        .select()
        .eq('group_id', groupId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => IbadatPayment.fromJson(e)).toList();
  }

  Future<List<IbadatPayment>> getPaymentsByProfile(
      String groupId, String profileId) async {
    final data = await _client
        .from('ibadat_payments')
        .select()
        .eq('group_id', groupId)
        .eq('profile_id', profileId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => IbadatPayment.fromJson(e)).toList();
  }

  Future<IbadatPayment> addPayment(IbadatPayment payment) async {
    final data = await _client
        .from('ibadat_payments')
        .insert(payment.toJson())
        .select()
        .single();
    return IbadatPayment.fromJson(data);
  }

  Future<void> updatePayment(IbadatPayment payment) async {
    await _client.from('ibadat_payments').update({
      'amount': payment.amount,
      'payment_date': payment.paymentDate?.toIso8601String().split('T').first,
      'paid_month': payment.paidMonth,
      'paid_extra': payment.paidExtra,
    }).eq('id', payment.id!);
  }

  Future<void> deletePayment(int id) async {
    await _client.from('ibadat_payments').delete().eq('id', id);
  }
}
