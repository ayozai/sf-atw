import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent }         from 'lightning/platformShowToastEvent';
import startRequalification       from '@salesforce/apex/RequalificationController.startRequalification';

export default class RequalificationWizard extends LightningElement {

    @api recordId;

    numberOfOpps  = 1;
    errorMessage  = '';
    isSubmitting  = false;

    handleNumberChange(event) {
        this.numberOfOpps = parseInt(event.target.value, 10);
        this.errorMessage = '';
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    async handleConfirm() {
        if (!this.numberOfOpps || this.numberOfOpps < 1) {
            this.errorMessage = 'Please enter a number greater than or equal to 1.';
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
                title:   'Processing started',
                message: 'Renewal opportunities are being created. You will receive a notification when done.',
                variant: 'success'
            }));
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (error) {
            this.isSubmitting = false;
            this.errorMessage = error?.body?.message || error?.message || 'An unexpected error occurred.';
        }
    }
}
