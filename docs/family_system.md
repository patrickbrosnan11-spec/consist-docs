# Family Invites and Roles System

This document describes the complete implementation of the family invites and roles system for the Consist project.

## Overview

The family system allows users to create families, invite members with specific roles, and manage family membership with role-based access control. The system supports two main roles:

- **Caregiver**: Full administrative access to family settings, member management, and content creation
- **Member**: Read-only access to family information with limited interaction capabilities

## Database Schema

### Core Tables

#### `families`
- `id`: UUID primary key
- `name`: Family display name
- `slug`: URL-friendly identifier (unique)
- `creator_user_id`: Reference to user who created the family
- `created_at`: Timestamp

#### `family_members`
- `family_id`: Reference to family
- `user_id`: Reference to user
- `role`: Either 'caregiver' or 'member'
- `display_name`: Optional display name for the family context
- `preferences_json`: JSON field for user preferences within the family

#### `invites`
- `id`: UUID primary key
- `family_id`: Reference to family
- `email`: Optional email for the invitee
- `role`: Role the invitee will have when they join
- `code`: Unique 8-character invite code
- `expires_at`: Expiration timestamp (7 days from creation)
- `created_by_user_id`: Reference to user who created the invite
- `accepted_by_user_id`: Reference to user who accepted the invite (null if pending)
- `accepted_at`: Timestamp when invite was accepted (null if pending)

#### `audit_log`
- `id`: UUID primary key
- `actor_user_id`: Reference to user performing the action
- `action`: Description of the action performed
- `entity_type`: Type of entity affected
- `entity_id`: ID of the entity affected
- `meta`: JSON field with additional context
- `created_at`: Timestamp

## API Endpoints

### Family Management

#### `POST /api/family`
Creates a new family and adds the creator as a caregiver.

**Request Body:**
```json
{
  "name": "Family Name",
  "slug": "family-slug"
}
```

**Response:**
```json
{
  "ok": true,
  "family": {
    "id": "uuid",
    "name": "Family Name",
    "slug": "family-slug",
    "createdAt": "timestamp"
  },
  "message": "Family created successfully! You have been added as a caregiver."
}
```

#### `GET /api/family?familyId={id}`
Retrieves family information, members, and pending invites.

**Response:**
```json
{
  "ok": true,
  "family": {
    "id": "uuid",
    "name": "Family Name",
    "slug": "family-slug"
  },
  "members": [...],
  "invites": [...],
  "userRole": "caregiver"
}
```

#### `GET /api/families`
Lists all families the authenticated user belongs to.

**Response:**
```json
{
  "ok": true,
  "families": [
    {
      "id": "uuid",
      "name": "Family Name",
      "slug": "family-slug",
      "role": "caregiver",
      "createdAt": "timestamp"
    }
  ],
  "count": 1
}
```

### Invite Management

#### `POST /api/invites`
Creates a new family invite.

**Request Body:**
```json
{
  "familyId": "uuid",
  "email": "optional@email.com",
  "role": "member"
}
```

**Response:**
```json
{
  "ok": true,
  "invite": {
    "id": "uuid",
    "code": "ABC12345",
    "expiresAt": "timestamp",
    "createdAt": "timestamp"
  },
  "family": {
    "id": "uuid",
    "name": "Family Name"
  },
  "role": "member",
  "inviteLink": "https://app.com/invite/ABC12345",
  "message": "Invite created successfully. It expires in 7 days."
}
```

#### `GET /api/invites/{code}`
Retrieves invite information (public endpoint, no auth required).

**Response:**
```json
{
  "ok": true,
  "invite": {
    "id": "uuid",
    "code": "ABC12345",
    "role": "member",
    "expiresAt": "timestamp",
    "createdAt": "timestamp"
  },
  "family": {
    "id": "uuid",
    "name": "Family Name"
  },
  "message": "You're being invited to join Family Name as a member."
}
```

#### `POST /api/invites/{code}`
Accepts an invite (requires authentication).

**Response:**
```json
{
  "ok": true,
  "family": {
    "id": "uuid",
    "name": "Family Name"
  },
  "role": "member",
  "message": "Welcome to Family Name! You've joined as a member."
}
```

#### `PATCH /api/invites/{id}`
Manages an existing invite (cancel or resend).

**Request Body:**
```json
{
  "action": "resend" // or "cancel"
}
```

#### `DELETE /api/invites/{id}`
Deletes an invite.

### Member Management

#### `PATCH /api/family/members/{id}`
Updates a member's role.

**Request Body:**
```json
{
  "role": "caregiver" // or "member"
}
```

#### `DELETE /api/family/members/{id}`
Removes a member from the family.

## Role-Based Access Control

### Caregiver Permissions
- Create and manage family invites
- Update member roles
- Remove family members
- Create/edit family events
- Manage rewards and redeemables
- Modify family settings

### Member Permissions
- View family information
- View family events
- Check in to events
- Redeem rewards (if allowed by caregivers)

### RLS Policies
The system uses Supabase Row Level Security (RLS) to enforce access control:

- **Read access**: Family members can read family data
- **Write access**: Only caregivers can modify family data
- **Invite management**: Only caregivers can create/manage invites
- **Member management**: Only caregivers can modify member roles or remove members

## Frontend Components

### Family Settings Page (`/settings/family`)
- Family selector dropdown
- Member list with role management
- Invite creation and management
- Role-based UI elements

### Family Creation Page (`/settings/family/create`)
- Form to create new families
- Automatic slug generation
- Validation and error handling

### Invite Acceptance Page (`/invite/{code}`)
- Public invite preview
- Authentication flow
- Invite acceptance

## Security Features

### Invite Security
- Unique 8-character codes
- 7-day expiration
- Single-use (cannot be accepted multiple times)
- Role-based access control

### Data Protection
- RLS policies prevent unauthorized access
- Audit logging for all actions
- Input validation and sanitization
- Role-based permission checks

### Family Integrity
- Cannot remove the last caregiver
- Cannot remove yourself from family
- Role changes require caregiver permissions

## Usage Examples

### Creating a Family
1. Navigate to `/settings/family/create`
2. Enter family name and slug
3. Submit to create family and become caregiver

### Inviting Members
1. Go to family settings
2. Click "Invite Member"
3. Choose role and optionally add email
4. Share the generated invite link

### Accepting Invites
1. Click invite link or enter code
2. Sign in or create account
3. Accept invitation to join family

### Managing Members
1. In family settings, view member list
2. Use role dropdown to change permissions
3. Remove members (caregivers only)

## Testing

Use the seed script `packages/db/seed/family-invites.seed.sql` to populate test data:

```bash
# Run the seed script in your database
psql -d your_database -f packages/db/seed/family-invites.seed.sql
```

This creates:
- Test families (Smith Family, Johnson Family)
- Test users with different roles
- Sample invites
- Audit log entries

## Future Enhancements

- Email notifications for invites
- Bulk invite operations
- Family templates and presets
- Advanced role hierarchies
- Family activity feeds
- Integration with external calendar systems
