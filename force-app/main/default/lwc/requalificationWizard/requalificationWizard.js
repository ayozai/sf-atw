import { LightningElement, api, track } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent }         from 'lightning/platformShowToastEvent';
import { loadScript }             from 'lightning/platformResourceLoader';
import startRequalification       from '@salesforce/apex/RequalificationController.startRequalification';
import getRequalificationContext  from '@salesforce/apex/RequalificationController.getRequalificationContext';
import searchGroupableOpps        from '@salesforce/apex/RequalificationController.searchGroupableOpps';
import startRegroupement          from '@salesforce/apex/RequalificationController.startRegroupement';
import SHEETJS_URL                from '@salesforce/resourceUrl/SheetJS';

export default class RequalificationWizard extends LightningElement {

    @api recordId;

    // Shared state
    currentStep   = 'choice'; // 'choice' | 'requalification' | 'grouping'
    errorMessage  = '';
    isLoading     = true;
    isSubmitting  = false;
    context       = null;

    // Requalification state
    numberOfOpps  = 1;
    references    = [];
    importedCount = 0;

    // Grouping state
    @track selectedOpps    = [];
    searchTerm             = '';
    @track searchResults   = [];
    isSearching            = false;
    newGroupOppName        = '';
    groupTargetAccountId   = null;

    connectedCallback() {
        loadScript(this, SHEETJS_URL).catch(() => {});
        getRequalificationContext({ opportunityId: this.recordId })
            .then(result => {
                this.context = result;
                if (result.isClosed) {
                    this.errorMessage = 'Cette opportunité est déjà fermée. La requalification n\'est disponible que pour les opportunités ouvertes.';
                }
            })
            .catch(err => {
                this.errorMessage = err?.body?.message || 'Erreur lors du chargement des données.';
            })
            .finally(() => { this.isLoading = false; });
    }

    // ── Step visibility ──────────────────────────────────────────────────────

    get showChoiceStep() {
        return this.currentStep === 'choice';
    }

    get showRequalificationStep() {
        return this.currentStep === 'requalification';
    }

    get showGroupingStep() {
        return this.currentStep === 'grouping';
    }

    // ── Requalification getters ───────────────────────────────────────────────

    get isOppClosed() {
        return this.context?.isClosed === true;
    }

    get isRequalConfirmDisabled() {
        return this.isSubmitting || this.isOppClosed;
    }

    get scenarioLabel() {
        if (!this.context) return '';
        return this.context.scenario === 1
            ? 'Scénario 1 — Contrat cadre sans contrats d\'application'
            : `Scénario 2 — ${this.context.appContractCount} contrat(s) d'application existant(s)`;
    }

    get contractConsequence() {
        if (!this.context) return '';
        return this.context.scenario === 1
            ? 'Le contrat cadre actuel passera en Réalloti, les nouvelles opportunités y seront liées'
            : 'Les contrats d\'application passeront en Réalloti';
    }

    get showReferenceInputs() {
        return this.numberOfOpps > 0 && this.numberOfOpps < 10;
    }

    get showImportButton() {
        return this.numberOfOpps >= 10;
    }

    get referenceRows() {
        return Array.from({ length: this.numberOfOpps }, (_, i) => ({
            key:   i,
            index: i + 1,
            label: `Référence opp ${i + 1}`,
            value: this.references[i] || ''
        }));
    }

    // ── Grouping getters ──────────────────────────────────────────────────────

    get groupTotalAmount() {
        return this.selectedOpps.reduce((sum, opp) => sum + (opp.amount || 0), 0);
    }

    get groupTotalAmountFormatted() {
        return this.groupTotalAmount.toLocaleString('fr-FR', { style: 'currency', currency: 'EUR' });
    }

    get groupAccountOptions() {
        const seen = new Set();
        const options = [];
        for (const opp of this.selectedOpps) {
            if (opp.accountId && !seen.has(opp.accountId)) {
                seen.add(opp.accountId);
                options.push({ label: opp.accountName || opp.accountId, value: opp.accountId });
            }
        }
        return options;
    }

    get isGroupConfirmDisabled() {
        return this.isSubmitting
            || this.selectedOpps.length < 2
            || !this.newGroupOppName
            || !this.groupTargetAccountId;
    }

    get isConfirmDisabled() {
        if (this.currentStep === 'requalification') return this.isRequalConfirmDisabled;
        if (this.currentStep === 'grouping')        return this.isGroupConfirmDisabled;
        return true;
    }

    get showConfirmButton() {
        return this.currentStep !== 'choice';
    }

    get showBackButton() {
        return this.currentStep !== 'choice';
    }

    get selectedOppsWithRemovable() {
        return this.selectedOpps.map((opp, idx) => ({
            ...opp,
            canRemove: idx !== 0 // origin opp (index 0) cannot be removed
        }));
    }

    get noSearchResultsMessage() {
        return this.searchResults.length === 0 && !this.isSearching && this.searchTerm.length >= 2
            ? 'Aucune opportunité trouvée pour cette recherche.'
            : '';
    }

    // ── Choice step handlers ──────────────────────────────────────────────────

    handleChoiceRequalification() {
        this.currentStep = 'requalification';
        this.errorMessage = '';
    }

    handleChoiceGrouping() {
        if (!this.context || this.isOppClosed) return;
        this.currentStep = 'grouping';
        this.errorMessage = '';

        // Pre-populate with the triggering opp
        this.selectedOpps = [{
            id:          this.recordId,
            name:        this.context.oppName,
            accountId:   this.context.accountId,
            accountName: this.context.accountName,
            contractRef: this.context.contractRef,
            amount:      this.context.amount || 0
        }];
        this.groupTargetAccountId = this.context.accountId;
        this.newGroupOppName = '';
        this.searchTerm = '';
        this.searchResults = [];
    }

    handleBack() {
        this.currentStep = 'choice';
        this.errorMessage = '';
    }

    // ── Requalification handlers ───────────────────────────────────────────────

    handleNumberChange(event) {
        this.numberOfOpps  = parseInt(event.target.value, 10);
        this.references    = [];
        this.importedCount = 0;
        this.errorMessage  = '';
    }

    handleReferenceChange(event) {
        const idx     = parseInt(event.target.dataset.index, 10);
        const updated = [...this.references];
        updated[idx]  = event.target.value;
        this.references = updated;
    }

    handleFileImport(event) {
        const file = event.target.files[0];
        if (!file) return;
        if (file.name.endsWith('.xlsx')) {
            const reader = new FileReader();
            reader.onload = (e) => {
                // eslint-disable-next-line no-undef
                const wb   = window.XLSX.read(e.target.result, { type: 'array' });
                const ws   = wb.Sheets[wb.SheetNames[0]];
                // eslint-disable-next-line no-undef
                const rows = window.XLSX.utils.sheet_to_json(ws, { header: 1 });
                this.references    = rows
                    .map(r => String(r[0] || '').trim())
                    .filter(v => v)
                    .slice(0, this.numberOfOpps);
                this.importedCount = this.references.length;
            };
            reader.readAsArrayBuffer(file);
        } else {
            const reader = new FileReader();
            reader.onload = (e) => {
                this.references    = e.target.result
                    .split(/\r?\n/)
                    .map(l => l.trim())
                    .filter(l => l)
                    .slice(0, this.numberOfOpps);
                this.importedCount = this.references.length;
            };
            reader.readAsText(file);
        }
    }

    // ── Grouping handlers ─────────────────────────────────────────────────────

    handleSearchTermChange(event) {
        this.searchTerm = event.target.value;
        if (this.searchTerm.length < 2) {
            this.searchResults = [];
        }
    }

    handleSearch() {
        if (this.searchTerm.length < 2) return;
        this.isSearching = true;
        this.searchResults = [];
        searchGroupableOpps({ currentOppId: this.recordId, searchTerm: this.searchTerm })
            .then(results => {
                const selectedIds = new Set(this.selectedOpps.map(o => o.id));
                this.searchResults = results.filter(r => !selectedIds.has(r.id));
            })
            .catch(err => {
                this.errorMessage = err?.body?.message || 'Erreur lors de la recherche.';
            })
            .finally(() => { this.isSearching = false; });
    }

    handleAddOpp(event) {
        const oppId = event.currentTarget.dataset.id;
        const opp   = this.searchResults.find(r => r.id === oppId);
        if (!opp) return;

        this.selectedOpps  = [...this.selectedOpps, opp];
        this.searchResults = this.searchResults.filter(r => r.id !== oppId);

        // If only one account option exists so far, auto-select it
        const options = this.groupAccountOptions;
        if (options.length === 1) {
            this.groupTargetAccountId = options[0].value;
        }
    }

    handleRemoveOpp(event) {
        const oppId = event.currentTarget.dataset.id;
        // Prevent removing the origin opp (first in list)
        if (this.selectedOpps.length > 0 && this.selectedOpps[0].id === oppId) return;
        this.selectedOpps = this.selectedOpps.filter(o => o.id !== oppId);
    }

    handleNewGroupOppNameChange(event) {
        this.newGroupOppName = event.target.value;
    }

    handleGroupTargetAccountChange(event) {
        this.groupTargetAccountId = event.detail.value;
    }

    // ── Confirm / Cancel ──────────────────────────────────────────────────────

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    async handleConfirm() {
        if (this.currentStep === 'requalification') {
            await this.handleRequalConfirm();
        } else if (this.currentStep === 'grouping') {
            await this.handleGroupConfirm();
        }
    }

    async handleRequalConfirm() {
        if (!this.numberOfOpps || this.numberOfOpps < 1) {
            this.errorMessage = 'Veuillez saisir un nombre supérieur ou égal à 1.';
            return;
        }
        this.isSubmitting = true;
        this.errorMessage = '';
        try {
            await startRequalification({
                opportunityId:   this.recordId,
                numberOfNewOpps: this.numberOfOpps,
                references:      this.references.length > 0 ? this.references : null
            });
            this.dispatchEvent(new ShowToastEvent({
                title:   'Traitement lancé',
                message: 'Les opportunités sont en cours de création. Vous recevrez une notification à la fin.',
                variant: 'success'
            }));
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (error) {
            this.isSubmitting = false;
            this.errorMessage = error?.body?.message || error?.message || 'Une erreur inattendue s\'est produite.';
        }
    }

    async handleGroupConfirm() {
        if (this.selectedOpps.length < 2) {
            this.errorMessage = 'Sélectionnez au moins 2 opportunités à regrouper.';
            return;
        }
        if (!this.newGroupOppName) {
            this.errorMessage = 'Veuillez saisir un libellé pour la nouvelle opportunité.';
            return;
        }
        if (!this.groupTargetAccountId) {
            this.errorMessage = 'Veuillez sélectionner un compte.';
            return;
        }

        this.isSubmitting = true;
        this.errorMessage = '';

        const extraIds = this.selectedOpps.slice(1).map(o => o.id);
        try {
            await startRegroupement({
                originOppId:      this.recordId,
                extraOppIds:      extraIds,
                newOppName:       this.newGroupOppName,
                targetAccountId:  this.groupTargetAccountId
            });
            this.dispatchEvent(new ShowToastEvent({
                title:   'Traitement lancé',
                message: 'Le regroupement est en cours. Vous recevrez une notification à la fin.',
                variant: 'success'
            }));
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (error) {
            this.isSubmitting = false;
            this.errorMessage = error?.body?.message || error?.message || 'Une erreur inattendue s\'est produite.';
        }
    }
}
