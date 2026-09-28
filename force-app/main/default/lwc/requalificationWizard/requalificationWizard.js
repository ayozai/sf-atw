import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent }         from 'lightning/platformShowToastEvent';
import startRequalification       from '@salesforce/apex/RequalificationController.startRequalification';
import getRequalificationContext  from '@salesforce/apex/RequalificationController.getRequalificationContext';

export default class RequalificationWizard extends LightningElement {

    @api recordId;

    numberOfOpps = 1;
    errorMessage = '';
    isLoading    = true;
    isSubmitting = false;
    context      = null;

    connectedCallback() {
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
            ? 'Scénario 1 — Nouveau contrat cadre sera créé'
            : `Scénario 2 — ${this.context.appContractCount} contrat(s) d'application existant(s)`;
    }

    get contractConsequence() {
        if (!this.context) return '';
        return this.context.scenario === 1
            ? 'Le contrat cadre actuel passera en Réalloti, un nouveau sera créé'
            : 'Les contrats d\'application passeront en Réalloti';
    }

    handleNumberChange(event) {
        this.numberOfOpps = parseInt(event.target.value, 10);
        this.errorMessage = '';
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
                opportunityId: this.recordId,
                numberOfNewOpps: this.numberOfOpps
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
