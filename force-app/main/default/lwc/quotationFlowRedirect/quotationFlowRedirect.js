import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class QuotationFlowRedirect extends NavigationMixin(LightningElement) {
    @api quotationId;

    connectedCallback() {
        if (this.quotationId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.quotationId,
                    objectApiName: 'Quotation__c',
                    actionName: 'view'
                }
            });
        }
    }
}