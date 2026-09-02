import 'package:flutter/material.dart';
import 'package:brightspeed_fiber_app/core/theme/app_theme.dart';
import 'package:brightspeed_fiber_app/core/utils/job_status_mapper.dart';

Future<String?> showJobStatusPicker(
  BuildContext context, {
  required String currentStatus,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      final maxHeight = MediaQuery.sizeOf(context).height * 0.55;

      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'Update Job Status',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: JobStatusMapper.pickerLabels.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final status = JobStatusMapper.pickerLabels[index];
                    final selected = status.toLowerCase() ==
                        currentStatus.toLowerCase();
                    return ListTile(
                      title: Text(status),
                      trailing: selected
                          ? const Icon(Icons.check, color: AppColors.navy)
                          : null,
                      onTap: () => Navigator.of(context).pop(status),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
