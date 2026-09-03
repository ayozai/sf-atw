import { LightningElement, api } from 'lwc';
import basePath from '@salesforce/community/basePath';

export default class RedirectToQuotation extends LightningElement {
    @api recordId;
    @api recordName;

    connectedCallback() {
        if (this.recordId) {
            const name = this.recordName || '';
            window.location.href = `${basePath}/quotation/${this.recordId}/${name}`;
        }
    }
}