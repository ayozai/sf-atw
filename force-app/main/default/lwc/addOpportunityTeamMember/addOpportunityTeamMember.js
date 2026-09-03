/**
 * @description     JavaScript controller for the Opportunity Team Self-Service LWC.
 *                  Handles member addition (Tab 1) and inline role editing (Tab 2).
 *
 *                  Key behaviours:
 *                  - recordId is received from the Quick Action context (Opportunity page).
 *                  - Roles are loaded once via a cacheable Apex call.
 *                  - Members are refreshed after each successful write operation.
 *                  - All errors from Apex (AuraHandledException) are surfaced to the user.
 *                  - Notifications (Chatter + Email) are handled server-side.
 *
 * @author          MGHARIANI
 * @date            2026-04-10
 * @feature         IACRM-90 — Opportunity Team Self-Service
 */
import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent }                      from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent }              from 'lightning/actions';
import { refreshApex }                         from '@salesforce/apex';

// Apex methods
import getTeamMembers      from '@salesforce/apex/OppTeamMemberController.getTeamMembers';
import getTeamRoles        from '@salesforce/apex/OppTeamMemberController.getTeamRoles';
import addTeamMember       from '@salesforce/apex/OppTeamMemberController.addTeamMember';
import updateTeamMemberRole from '@salesforce/apex/OppTeamMemberController.updateTeamMemberRole';

// Custom Labels (bilingual — translations configured via Translation Workbench)
import labelTitle          from '@salesforce/label/c.OTM_Title';
import labelTabAdd         from '@salesforce/label/c.OTM_Tab_AddMember';
import labelTabCurrent     from '@salesforce/label/c.OTM_Tab_CurrentMembers';
import labelUser           from '@salesforce/label/c.OTM_Label_User';
import labelRole           from '@salesforce/label/c.OTM_Label_Role';
import labelAccess         from '@salesforce/label/c.OTM_Label_Access';
import labelAccessValue    from '@salesforce/label/c.OTM_Label_AccessValue';
import labelAdd            from '@salesforce/label/c.OTM_Tab_AddMember';
import labelSuccessAdd     from '@salesforce/label/c.OTM_Success_Add';
import labelSuccessRole    from '@salesforce/label/c.OTM_Success_Role';
import labelNoMembers      from '@salesforce/label/c.OTM_Label_NoMembers';

export default class AddOpportunityTeamMember extends LightningElement {

    // ─── Public property — provided by Quick Action context ─────────────────────
    @api recordId; // Opportunity Id

    // ─── Tracked state ───────────────────────────────────────────────────────────
    @track selectedUserId  = null;
    @track selectedRole    = '';
    @track draftValues     = [];
    @track errorMessage    = null;
    @track isLoading       = false;
    @track isLoadingMembers = false;

    activeTab = 'add';

    // ─── Wire results ────────────────────────────────────────────────────────────
    _wiredMembersResult; // kept for refreshApex
    teamMembers  = [];
    roleOptions  = [];

    // ─── Custom Labels ───────────────────────────────────────────────────────────
    labels = {
        title           : labelTitle,
        tabAdd          : labelTabAdd,
        tabCurrent      : labelTabCurrent,
        labelUser       : labelUser,
        labelRole       : labelRole,
        labelAccess     : labelAccess,
        labelAccessValue: labelAccessValue,
        buttonAdd       : 'Add',       // inline — label reuses OTM_Tab_AddMember verb
        buttonCancel    : 'Cancel',
        rolePlaceholder : '— Optional —',
        successAdd      : labelSuccessAdd,
        successRole     : labelSuccessRole,
        noMembers       : labelNoMembers,
        errorTitle      : 'Error'
    };

    // ─── Datatable column filter for User lookup ──────────────────────────────────
    userFilter = {
        criteria: [{ fieldPath: 'IsActive', operator: 'eq', value: true }]
    };

    // ─── Datatable columns definition ────────────────────────────────────────────
    get columns() {
        return [
            {
                label        : 'Name',
                fieldName    : 'userName',
                type         : 'text',
                sortable     : true,
                editable     : false
            },
            {
                label        : this.labels.labelRole,
                fieldName    : 'TeamMemberRole',
                type         : 'text',
                editable     : true
            },
            {
                label        : this.labels.labelAccess,
                fieldName    : 'OpportunityAccessLevel',
                type         : 'text',
                editable     : false
            }
        ];
    }

    // ─── Derived state ───────────────────────────────────────────────────────────
    get isAddDisabled() {
        return !this.selectedUserId || this.isLoading;
    }

    get hasNoMembers() {
        return !this.isLoadingMembers && (!this.teamMembers || this.teamMembers.length === 0);
    }

    // ─────────────────────────────────────────────────────────────────────────────
    //  WIRE — Load team roles (cacheable, loaded once)
    // ─────────────────────────────────────────────────────────────────────────────

    @wire(getTeamRoles)
    wiredRoles({ error, data }) {
        if (data) {
            this.roleOptions = data.map(r => ({ label: r.label, value: r.value }));
        } else if (error) {
            this.showError(error);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────────
    //  WIRE — Load current team members
    // ─────────────────────────────────────────────────────────────────────────────

    @wire(getTeamMembers, { opportunityId: '$recordId' })
    wiredMembers(result) {
        this._wiredMembersResult = result;
        const { error, data } = result;
        if (data) {
            // Flatten User.Name for datatable display
            this.teamMembers = data.map(m => ({
                ...m,
                userName: m.User ? m.User.Name : ''
            }));
        } else if (error) {
            this.showError(error);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────────
    //  HANDLERS — Tab 1 : Add Member
    // ─────────────────────────────────────────────────────────────────────────────

    handleTabChange(event) {
        this.activeTab = event.target.value;
        this.clearError();
    }

    handleUserSelect(event) {
        this.selectedUserId = event.detail.recordId;
        this.clearError();
    }

    handleRoleChange(event) {
        this.selectedRole = event.detail.value;
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    async handleAddMember() {
        this.clearError();
        this.isLoading = true;
        try {
            await addTeamMember({
                opportunityId  : this.recordId,
                userId         : this.selectedUserId,
                teamMemberRole : this.selectedRole || null
            });
            this.showToast('success', this.labels.successAdd);
            this.resetAddForm();
            await refreshApex(this._wiredMembersResult);
        } catch (error) {
            this.showError(error);
        } finally {
            this.isLoading = false;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────────
    //  HANDLERS — Tab 2 : Current Members (inline role editing)
    // ─────────────────────────────────────────────────────────────────────────────

    async handleSaveRoles(event) {
        const draftRows = event.detail.draftValues;
        this.clearError();
        this.isLoadingMembers = true;

        try {
            // Fire one update call per modified row sequentially
            for (const draft of draftRows) {
                await updateTeamMemberRole({
                    teamMemberId : draft.Id,
                    newRole      : draft.TeamMemberRole
                });
            }
            this.draftValues = [];
            this.showToast('success', this.labels.successRole);
            await refreshApex(this._wiredMembersResult);
        } catch (error) {
            this.showError(error);
        } finally {
            this.isLoadingMembers = false;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────────
    //  PRIVATE HELPERS
    // ─────────────────────────────────────────────────────────────────────────────

    resetAddForm() {
        this.selectedUserId = null;
        this.selectedRole   = '';
    }

    clearError() {
        this.errorMessage = null;
    }

    /**
     * @description Extracts a user-facing message from an Apex error and sets it
     *              on the errorMessage tracked property for display in the banner.
     * @param {Object} error  The error object from an Apex call.
     */
    showError(error) {
        if (error && error.body && error.body.message) {
            this.errorMessage = error.body.message;
        } else if (error && error.message) {
            this.errorMessage = error.message;
        } else {
            this.errorMessage = 'An unexpected error occurred. Please try again.';
        }
    }

    /**
     * @description Fires a ShowToastEvent.
     * @param {string} variant  'success' | 'error' | 'warning' | 'info'
     * @param {string} message  Toast message body.
     */
    showToast(variant, message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title   : variant === 'success' ? 'Success' : 'Error',
                message : message,
                variant : variant
            })
        );
    }
}