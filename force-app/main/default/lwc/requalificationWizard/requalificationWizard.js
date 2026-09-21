import { LightningElement, api, wire, track } from 'lwc';
import { CloseActionScreenEvent }    from 'lightning/actions';
import { ShowToastEvent }            from 'lightning/platformShowToastEvent';
import { getRecordNotifyChange }     from 'lightning/uiRecordApi';

import getOpportunityContext  from '@salesforce/apex/RequalificationController.getOpportunityContext';
import executeRequalification from '@salesforce/apex/RequalificationController.executeRequalification';

import labelTitle               from '@salesforce/label/c.requalif_title';
import labelStep1               from '@salesforce/label/c.requalif_step1';
import labelStep2               from '@salesforce/label/c.requalif_step2';
import labelStep3               from '@salesforce/label/c.requalif_step3';
import labelCancel              from '@salesforce/label/c.requalif_cancel';
import labelNext                from '@salesforce/label/c.requalif_next';
import labelBack                from '@salesforce/label/c.requalif_back';
import labelConfirm             from '@salesforce/label/c.requalif_confirm';
import labelSuccess             from '@salesforce/label/c.requalif_success';
import labelErrorGeneric        from '@salesforce/label/c.requalif_error_generic';
import labelAddOpp              from '@salesforce/label/c.requalif_add_opp';
import labelNbOpps              from '@salesforce/label/c.requalif_nb_opps';
import labelOppsToCreate        from '@salesforce/label/c.requalif_opps_to_create';
import labelOppsToClose         from '@salesforce/label/c.requalif_opps_to_close';
import labelRenewalsToClose     from '@salesforce/label/c.requalif_renewals_to_close';
import labelDevOpps             from '@salesforce/label/c.requalif_dev_opps';
import labelApplicationContract from '@salesforce/label/c.requalif_application_contract';
import labelLoading             from '@salesforce/label/c.requalif_loading';

const STEP_CHOICE = 'choice';
const STEP_FORM   = 'form';
const STEP_RECAP  = 'recap';

const SUB_ALLOT_OPP = 'Allotissement Opp';
const SUB_ALLOT_CC  = 'Allotissement CC';
const SUB_REALLOC   = 'Réallocation périmètre';

export default class RequalificationWizard extends LightningElement {

    @api recordId;

    // ── Labels ──────────────────────────────────────────────────────────────
    label = {
        title:               labelTitle,
        step1:               labelStep1,
        step2:               labelStep2,
        step3:               labelStep3,
        cancel:              labelCancel,
        next:                labelNext,
        back:                labelBack,
        confirm:             labelConfirm,
        success:             labelSuccess,
        errorGeneric:        labelErrorGeneric,
        addOpp:              labelAddOpp,
        nbOpps:              labelNbOpps,
        oppsToCreate:        labelOppsToCreate,
        oppsToClose:         labelOppsToClose,
        renewalsToClose:     labelRenewalsToClose,
        devOpps:             labelDevOpps,
        applicationContract: labelApplicationContract,
        loading:             labelLoading
    };

    // ── State ────────────────────────────────────────────────────────────────
    @track step           = STEP_CHOICE;
    @track subStage       = '';
    @track newOpportunities   = [];   // [{key, index, name, closeDate, contractId}]
    @track devOpportunities   = [];   // réallocation — [{key, name, closeDate}]
    @track openRenewalOpps    = [];   // [{value, label, checked}]
    @track applicationContracts = []; // [{value, label}]
             isSubmitting  = false;
             originOppName = '';
             contextError  = '';
    _oppKeyCounter = 0;

    // ── Wire ─────────────────────────────────────────────────────────────────
    @wire(getOpportunityContext, { originOppId: '$recordId' })
    wiredContext({ data, error }) {
        if (data) {
            this.originOppName        = data.originOppName;
            this.applicationContracts = data.applicationContracts || [];
            this.openRenewalOpps = (data.openRenewalOpps || []).map(o => ({
                value:   o.value,
                label:   o.label,
                checked: false
            }));
            this.contextError = '';
        } else if (error) {
            this.contextError = error?.body?.message || error?.message || this.label.errorGeneric;
        }
    }

    // ── Computed — état global ────────────────────────────────────────────────
    get isLoading() {
        return !this.originOppName && !this.contextError;
    }

    get hasContextError() {
        return !!this.contextError;
    }

    get isReady() {
        return !!this.originOppName;
    }

    // ── Computed — navigation ────────────────────────────────────────────────
    get isStepChoice() { return this.step === STEP_CHOICE; }
    get isStepForm()   { return this.step === STEP_FORM;   }
    get isStepRecap()  { return this.step === STEP_RECAP;  }

    get isAllotissementCC() { return this.subStage === SUB_ALLOT_CC; }
    get isReallocation()    { return this.subStage === SUB_REALLOC;  }

    get showCancelButton()  { return !this.isSubmitting; }
    get showBackButton()    { return this.step !== STEP_CHOICE; }
    get showNextButton()    { return this.step !== STEP_RECAP;  }
    get showConfirmButton() { return this.step === STEP_RECAP;  }

    get isNextDisabled() {
        if (this.isStepChoice) return !this.subStage;
        if (this.isStepForm)   return !this._isFormValid();
        return false;
    }

    // ── Computed — options ────────────────────────────────────────────────────
    get branchOptions() {
        return [
            { label: SUB_ALLOT_OPP, value: SUB_ALLOT_OPP },
            { label: SUB_ALLOT_CC,  value: SUB_ALLOT_CC  },
            { label: SUB_REALLOC,   value: SUB_REALLOC   }
        ];
    }

    get newOpportunityCount() {
        return this.newOpportunities.length || 1;
    }

    get hasOpenRenewalOpps() {
        return this.openRenewalOpps.length > 0;
    }

    get hasCheckedOpps() {
        return this.openRenewalOpps.some(o => o.checked);
    }

    // ── Computed — récapitulatif ──────────────────────────────────────────────
    get recapNewOpportunities() {
        if (this.isReallocation) return this.devOpportunities;
        return this.newOpportunities;
    }

    get recapItemsToClose() {
        return this.openRenewalOpps.filter(o => o.checked);
    }

    // ── Handlers — navigation ────────────────────────────────────────────────
    handleBranchChange(event) {
        this.subStage = event.detail.value;
        // Réinitialise les listes au changement de branche
        this.newOpportunities = [this._buildNewOppEntry()];
        this.devOpportunities = [this._buildNewOppEntry()];
    }

    handleNext() {
        if (this.step === STEP_CHOICE) {
            // Initialise la liste d'opps avec 1 entrée par défaut
            if (this.newOpportunities.length === 0) {
                this.newOpportunities = [this._buildNewOppEntry()];
            }
            if (this.devOpportunities.length === 0) {
                this.devOpportunities = [this._buildNewOppEntry()];
            }
            this.step = STEP_FORM;
        } else if (this.step === STEP_FORM) {
            this.step = STEP_RECAP;
        }
    }

    handleBack() {
        if (this.step === STEP_FORM)   this.step = STEP_CHOICE;
        if (this.step === STEP_RECAP)  this.step = STEP_FORM;
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    // ── Handlers — formulaire Allotissement ──────────────────────────────────
    handleOpportunityCountChange(event) {
        const count = Math.max(1, Math.min(20, parseInt(event.detail.value, 10) || 1));
        const current = this.newOpportunities.length;
        if (count > current) {
            for (let i = current; i < count; i++) {
                this.newOpportunities = [...this.newOpportunities, this._buildNewOppEntry()];
            }
        } else if (count < current) {
            this.newOpportunities = this.newOpportunities.slice(0, count);
        }
    }

    handleNewOppFieldChange(event) {
        const key   = parseInt(event.target.dataset.key, 10);
        const field = event.target.dataset.field;
        this.newOpportunities = this.newOpportunities.map(opp =>
            opp.key === key ? { ...opp, [field]: event.detail.value } : opp
        );
    }

    // ── Handlers — formulaire Réallocation ───────────────────────────────────
    handleRenewalOppCheck(event) {
        const id = event.target.dataset.id;
        this.openRenewalOpps = this.openRenewalOpps.map(o =>
            o.value === id ? { ...o, checked: event.detail.checked } : o
        );
    }

    handleDevOppFieldChange(event) {
        const key   = parseInt(event.target.dataset.key, 10);
        const field = event.target.dataset.field;
        this.devOpportunities = this.devOpportunities.map(opp =>
            opp.key === key ? { ...opp, [field]: event.detail.value } : opp
        );
    }

    handleAddDevOpportunity() {
        this.devOpportunities = [...this.devOpportunities, this._buildNewOppEntry()];
    }

    // ── Confirmation & appel Apex ─────────────────────────────────────────────
    handleConfirm() {
        this.isSubmitting = true;

        const request = {
            originOppId:      this.recordId,
            subStage:         this.subStage,
            newOpportunities: this._buildNewOppsPayload(),
            oppIdsToClose:    this.openRenewalOpps
                                  .filter(o => o.checked)
                                  .map(o => o.value)
        };

        executeRequalification({ request })
            .then(() => {
                this._showToast(this.label.success, '', 'success');
                getRecordNotifyChange([{ recordId: this.recordId }]);
                this.dispatchEvent(new CloseActionScreenEvent());
            })
            .catch(error => {
                const msg = error?.body?.message || error?.message || this.label.errorGeneric;
                this._showToast('Erreur', msg, 'error');
            })
            .finally(() => {
                this.isSubmitting = false;
            });
    }

    // ── Helpers privés ────────────────────────────────────────────────────────
    _buildNewOppEntry() {
        this._oppKeyCounter += 1;
        return {
            key:        this._oppKeyCounter,
            index:      this._oppKeyCounter,
            name:       '',
            closeDate:  '',
            contractId: ''
        };
    }

    _buildNewOppsPayload() {
        const list = this.isReallocation ? this.devOpportunities : this.newOpportunities;
        return list.map(o => ({
            name:       o.name,
            closeDate:  o.closeDate,
            contractId: o.contractId || null
        }));
    }

    _isFormValid() {
        if (this.isReallocation) {
            return this.devOpportunities.every(o => o.name && o.closeDate);
        }
        return this.newOpportunities.every(o => {
            if (!o.name || !o.closeDate) return false;
            if (this.isAllotissementCC && !o.contractId) return false;
            return true;
        });
    }

    _showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
