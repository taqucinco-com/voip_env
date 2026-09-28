// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'call_record.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CallRecord _$CallRecordFromJson(Map<String, dynamic> json) => CallRecord(
  caller: json['caller'] as String,
  callee: json['callee'] as String,
  status: json['status'] as String,
);

Map<String, dynamic> _$CallRecordToJson(CallRecord instance) =>
    <String, dynamic>{
      'caller': instance.caller,
      'callee': instance.callee,
      'status': instance.status,
    };
