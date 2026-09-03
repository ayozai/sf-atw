import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';
import STATUS_FIELD from '@salesforce/schema/Quotation__c.Status__c';

const TRIGGER_STATUS = 'Sent to customer';

export default class QuotationFlowBtn extends NavigationMixin(LightningElement) {
    @api recordId;
    @api recordName;
    showFlow = false;
    flowInputVariables = [];

    @wire(getRecord, { recordId: '$recordId', fields: [STATUS_FIELD] })
    record;

    get showButton() {
        if (!this.record?.data) return false;
        const status = getFieldValue(this.record.data, STATUS_FIELD);
        return status === TRIGGER_STATUS;
    }

    handleClick() {
        this.flowInputVariables = [
            { name: 'recordId', type: 'String', value: this.recordId }
        ];
        this.showFlow = true;
    }

    handleFlowStatusChange(event) {
        if (['FINISHED', 'FINISHED_SCREEN'].includes(event.detail.status)) {
            this.showFlow = false;
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.recordId,
                    objectApiName: 'Quotation__c',
                    actionName: 'view'
                }
            });
        }
    }
}