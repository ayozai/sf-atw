import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent }         from 'lightning/platformShowToastEvent';
import { loadScript }             from 'lightning/platformResourceLoader';
import startRequalification       from '@salesforce/apex/RequalificationController.startRequalification';
import getRequalificationContext  from '@salesforce/apex/RequalificationController.getRequalificationContext';
import SHEETJS_URL                from '@salesforce/resourceUrl/SheetJS';

export default class RequalificationWizard extends LightningElement {

    @api recordId;

    numberOfOpps  = 1;
    errorMessage  = '';
    isLoading     = true;
    isSubmitting  = false;
    context       = null;
    references    = [];
    importedCount = 0;

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

    get isOppClosed() {
        return this.context?.isClosed === true;
    }

    get isConfirmDisabled() {
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

    handleNumberChange(event) {
        this.numberOfOpps   = parseInt(event.target.value, 10);
        this.references     = [];
        this.importedCount  = 0;
        this.errorMessage   = '';
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

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    async handleConfirm() {
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
}
