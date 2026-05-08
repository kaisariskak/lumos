import '../models/ibadat_profile.dart';

List<IbadatProfile> visibleGroupMembers(
  Iterable<IbadatProfile> members, {
  required String adminId,
}) {
  return members.where((member) => member.id != adminId).toList();
}
