import { db } from '../db/pool.js';
import { mapNotificationRow } from './demandService.js';
/** Fetch a user's notifications, newest first. */
export async function listNotifications(userId) {
    const { rows } = await db.query(`SELECT id, user_id, title, subtitle, type, is_read, created_at
     FROM notifications
     WHERE user_id = $1
     ORDER BY created_at DESC
     LIMIT 100`, [userId]);
    return rows.map(mapNotificationRow);
}
/** Count unread notifications for a user. */
export async function countUnread(userId) {
    const { rows } = await db.query(`SELECT COUNT(*)::text AS count
     FROM notifications
     WHERE user_id = $1 AND is_read = false`, [userId]);
    return parseInt(rows[0]?.count ?? '0', 10);
}
/** Mark a single notification as read. */
export async function markOneRead(notificationId, userId) {
    const { rowCount } = await db.query(`UPDATE notifications
     SET is_read = true
     WHERE id = $1 AND user_id = $2`, [notificationId, userId]);
    return (rowCount ?? 0) > 0;
}
/** Mark all of a user's notifications as read. Returns number updated. */
export async function markAllRead(userId) {
    const { rowCount } = await db.query(`UPDATE notifications
     SET is_read = true
     WHERE user_id = $1 AND is_read = false`, [userId]);
    return { updated: rowCount ?? 0 };
}
//# sourceMappingURL=notificationService.js.map