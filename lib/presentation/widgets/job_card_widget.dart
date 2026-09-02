import 'package:flutter/material.dart';
import 'package:brightspeed_fiber_app/core/theme/app_theme.dart';
import 'package:brightspeed_fiber_app/core/utils/display_value.dart';
import 'package:brightspeed_fiber_app/domain/entities/feature_flags.dart';
import 'package:brightspeed_fiber_app/domain/entities/job.dart';
import 'package:brightspeed_fiber_app/presentation/widgets/job_status_option.dart';

class JobCardWidget extends StatelessWidget {
  const JobCardWidget({
    super.key,
    required this.job,
    required this.flags,
    required this.onStatusTap,
  });

  final Job job;
  final FeatureFlags flags;
  final VoidCallback onStatusTap;

  @override
  Widget build(BuildContext context) {
    final statusOption = JobStatusOption.forLabel(job.status);
    final showNotesOrCv = flags.jobNotes || flags.jobCv;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      elevation: 1,
      color: AppColors.cardPink,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: Colors.grey.shade400),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Job: ${job.index}/${job.total}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    displayValue(job.name),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
                const Icon(Icons.work_outline, size: 18, color: AppColors.red),
                const SizedBox(width: 4),
                _pill(displayValue(job.brand), AppColors.red, fontSize: 9),
                if (flags.jobStatus) ...[
                  const SizedBox(width: 4),
                  _pill(displayValue(job.status), statusOption.color),
                ],
              ],
            ),
            if (flags.jobPhone) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.phone, color: AppColors.blue, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      displayValue(job.phone),
                      style: TextStyle(
                        color: job.phone.trim().isEmpty
                            ? Colors.grey.shade600
                            : AppColors.blue,
                        fontSize: 12,
                        decoration: job.phone.trim().isEmpty
                            ? TextDecoration.none
                            : TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (flags.jobLoction || showNotesOrCv) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (flags.jobLoction) ...[
                    const Icon(Icons.location_on, color: AppColors.blue, size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        displayValue(job.address),
                        style: TextStyle(
                          color: job.address.trim().isEmpty
                              ? Colors.grey.shade600
                              : AppColors.blue,
                          fontSize: 12,
                          decoration: job.address.trim().isEmpty
                              ? TextDecoration.none
                              : TextDecoration.underline,
                        ),
                      ),
                    ),
                  ] else
                    const Spacer(),
                  if (showNotesOrCv)
                    Column(
                      children: [
                        if (flags.jobNotes)
                          _actionChip('Notes', AppColors.lightOrange),
                        if (flags.jobNotes && flags.jobCv)
                          const SizedBox(height: 4),
                        if (flags.jobCv) _actionChip('CV', AppColors.blue),
                      ],
                    ),
                ],
              ),
            ],
            if (flags.jobDetails) ...[
              const Divider(height: 16),
              _gridRow('Service Type', job.serviceType, 'Order #', job.orderNumber),
              _gridRow(
                'Tech Service Action',
                job.techServiceAction,
                'Job ID',
                job.jobId,
              ),
              _gridRow('Job Timeframe', job.jobTimeframe, 'Due Date', job.dueDate),
              _gridRow(
                'Circuit ID',
                job.circuitId,
                'Dispatch Job Type',
                job.dispatchJobType,
              ),
              _gridRow(
                'Migrating From',
                job.migratingFrom,
                'Dispatch Task',
                job.dispatchTask,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (flags.jobTruckInventory) ...[
                  _statusCircle(Icons.local_shipping, AppColors.green),
                  const SizedBox(width: 8),
                ],
                if (flags.jobCDD) ...[
                  _statusCircle(null, Colors.grey, label: 'CDD'),
                  const SizedBox(width: 8),
                ],
                Row(
                  children: [
                    const Icon(Icons.speed, size: 16),
                    const SizedBox(width: 2),
                    Text(
                      displayValue(job.speed),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ],
                ),
                const Spacer(),
                if (flags.jobStatus)
                  _JobStatusButton(
                    status: displayValue(job.status),
                    color: statusOption.color,
                    onTap: onStatusTap,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, Color color, {double fontSize = 10}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(color: Colors.white, fontSize: fontSize),
      ),
    );
  }

  Widget _actionChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color)),
    );
  }

  Widget _gridRow(String l1, String v1, String l2, String v2) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _labelValue(l1, v1)),
          Expanded(child: _labelValue(l2, v2)),
        ],
      ),
    );
  }

  Widget _labelValue(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 10, color: Colors.black),
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          TextSpan(
            text: displayValue(value),
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _statusCircle(IconData? icon, Color color, {String? label}) {
    return CircleAvatar(
      radius: 14,
      backgroundColor: color,
      child: icon != null
          ? Icon(icon, size: 14, color: Colors.white)
          : Text(
              label ?? '',
              style: const TextStyle(fontSize: 8, color: Colors.white),
            ),
    );
  }
}

class _JobStatusButton extends StatelessWidget {
  const _JobStatusButton({
    required this.status,
    required this.color,
    required this.onTap,
  });

  final String status;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                status,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
