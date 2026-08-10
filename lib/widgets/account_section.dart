import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/account_deletion_service.dart';

typedef AccountDeletionSessionFinisher = Future<void> Function();

class AccountSection extends StatefulWidget {
  final AppStrings strings;
  final VoidCallback onLogout;
  final Future<AccountDeletionResult> Function() onDeleteAccount;
  final AccountDeletionSessionFinisher? onFinishDeletedAccountSession;
  final VoidCallback? onDeleted;
  final bool canDeleteAccount;

  const AccountSection({
    super.key,
    required this.strings,
    required this.onLogout,
    required this.onDeleteAccount,
    this.onFinishDeletedAccountSession,
    this.onDeleted,
    this.canDeleteAccount = true,
  });

  @override
  State<AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<AccountSection> {
  bool _isDeleting = false;

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.strings.deleteAccountTitle),
        content: Text(widget.strings.deleteAccountBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(widget.strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
            ),
            child: Text(widget.strings.deleteForever),
          ),
        ],
      ),
    );

    if (!mounted) {
      return;
    }

    if (confirmed != true || _isDeleting) {
      return;
    }

    setState(() => _isDeleting = true);
    final result = await widget.onDeleteAccount();
    if (!mounted) {
      return;
    }

    setState(() => _isDeleting = false);
    await _showResult(result);
  }

  Future<void> _showResult(AccountDeletionResult result) async {
    final message = switch (result.status) {
      AccountDeletionStatus.deleted => widget.strings.deleteAccountSuccess,
      AccountDeletionStatus.noSession => widget.strings.deleteAccountNoSession,
      AccountDeletionStatus.superAdminForbidden =>
        widget.strings.deleteAccountSuperAdminForbidden,
      AccountDeletionStatus.groupOwnershipBlocked =>
        widget.strings.deleteAccountGroupOwnershipBlocked,
      AccountDeletionStatus.retryableFailure =>
        widget.strings.deleteAccountRetryableFailure,
      AccountDeletionStatus.unknownFailure =>
        widget.strings.deleteAccountUnknownFailure,
    };
    final appleNote =
        result.status == AccountDeletionStatus.deleted && !result.appleRevoked
            ? widget.strings.deleteAccountAppleManualRevoke
            : null;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: appleNote == null
            ? Text(message)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message),
                  const SizedBox(height: 4),
                  Text(appleNote),
                ],
              ),
      ),
    );

    if (result.status == AccountDeletionStatus.deleted) {
      widget.onDeleted?.call();
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) {
        await widget.onFinishDeletedAccountSession?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_circle_rounded,
                color: Color(0xFF94A3B8),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                widget.strings.accountSectionTitle,
                style: const TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isDeleting ? null : widget.onLogout,
              icon: const Icon(Icons.logout, size: 18),
              label: Text(widget.strings.signOutOfAccount),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE2E8F0),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          if (widget.canDeleteAccount) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isDeleting ? null : _confirmDelete,
                icon: _isDeleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline, size: 18),
                label: Text(
                  _isDeleting
                      ? widget.strings.deletingAccount
                      : widget.strings.deleteAccount,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  backgroundColor:
                      const Color(0xFFEF4444).withValues(alpha: 0.08),
                  side: BorderSide(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.45),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
