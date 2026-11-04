import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/complaint_model.dart';
import 'complaint_card_widget.dart';

class ComplaintKanbanColumn extends StatelessWidget {
  final String title;
  final ComplaintStatus status;
  final List<ComplaintModel> complaints;
  final Color headerColor;
  final Function(ComplaintModel) onComplaintTap;
  final Function(ComplaintModel) onAssignTapped;
  final Function(ComplaintModel, ComplaintStatus) onStatusChange;
  final bool canManage;

  const ComplaintKanbanColumn({
    super.key,
    required this.title,
    required this.status,
    required this.complaints,
    required this.headerColor,
    required this.onComplaintTap,
    required this.onAssignTapped,
    required this.onStatusChange,
    required this.canManage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Column Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: headerColor.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(color: headerColor.withOpacity(0.2), width: 2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: headerColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: headerColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${complaints.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: headerColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Cards List (With DragTarget if Drag-and-Drop is supported)
          Expanded(
            child: DragTarget<ComplaintModel>(
              onWillAcceptWithDetails: (details) {
                return details.data.status != status;
              },
              onAcceptWithDetails: (details) {
                onStatusChange(details.data, status);
              },
              builder: (context, candidateData, rejectedData) {
                final isHovered = candidateData.isNotEmpty;

                if (complaints.isEmpty) {
                  return Container(
                    decoration: BoxDecoration(
                      color: isHovered ? headerColor.withOpacity(0.06) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_outlined, size: 36, color: Colors.grey.shade300),
                          const SizedBox(height: 8),
                          Text(
                            isHovered ? 'Lepas untuk memindahkan status' : 'Tidak ada tiket',
                            style: TextStyle(
                              fontSize: 12,
                              color: isHovered ? headerColor : AppTheme.textMuted,
                              fontWeight: isHovered ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Container(
                  color: isHovered ? headerColor.withOpacity(0.06) : Colors.transparent,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: complaints.length,
                    itemBuilder: (context, index) {
                      final item = complaints[index];

                      final card = ComplaintCardWidget(
                        complaint: item,
                        isKanban: true,
                        canManage: canManage,
                        onTap: () => onComplaintTap(item),
                        onAssignTapped: canManage ? () => onAssignTapped(item) : null,
                        onStatusChanged: canManage
                            ? (newSt) => onStatusChange(item, newSt)
                            : null,
                      );

                      if (!canManage) {
                        return card;
                      }

                      // Drag and drop wrapper for web/desktop
                      return Draggable<ComplaintModel>(
                        data: item,
                        feedback: Material(
                          elevation: 4.0,
                          borderRadius: BorderRadius.circular(12),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 300),
                            child: card,
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.35,
                          child: card,
                        ),
                        child: card,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
