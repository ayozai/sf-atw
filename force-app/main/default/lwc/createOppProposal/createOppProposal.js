import { LightningElement, api, track } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { updateRecord, getRecordNotifyChange } from 'lightning/uiRecordApi';
import getOpportunity from '@salesforce/apex/CreateOppProposalController.GetOpportunity';
import getGroupOptions from '@salesforce/apex/CreateOppProposalController.GetGroupOptions';
import createProposalFolder from '@salesforce/apex/CreateOppProposalController.CreateProposalFolder';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import cancel from "@salesforce/label/c.cancelProposal";
import create from "@salesforce/label/c.createProposal";
import folderAlreadyExistsLabel from "@salesforce/label/c.folderAlreadyExistsLabel";
import folderIdLabel from "@salesforce/label/c.folderIdLabel";
import loadingLabel from "@salesforce/label/c.loadingLabel";
import pleaseSelectGroupOppLabel from "@salesforce/label/c.pleaseSelectGroupOppLabel";
import proposalStudioTitle from "@salesforce/label/c.proposalStudioTitle";

const OPP_ID_FIELD = 'Id';
const OPP_NAME_FIELD = 'Name';
const OPP_ACC_FIELD = 'Account.Name';
const OPP_PS111_FOLDER_ID_FIELD = 'PS111_Folder_ID__c';

export default class CreateOppProposal extends LightningElement {
    @api recordId;
    @track opp = undefined;
    @track loading = true;
    @track folderId = undefined;
    @track selectedUnitId = undefined;
    @track groupPicklistOptions = [];
    @track loadingMessage = '';

    initialized = false;

    label = {
        cancel,
        create,
        folderAlreadyExistsLabel,
        folderIdLabel,
        loadingLabel,
        pleaseSelectGroupOppLabel,
        proposalStudioTitle
    };

    renderedCallback() {
        if (this.initialized || !this.recordId) return;
        this.initialized = true;

        getOpportunity({
            recordId: this.recordId,
            fields: [OPP_ID_FIELD, OPP_NAME_FIELD, OPP_PS111_FOLDER_ID_FIELD, OPP_ACC_FIELD]
        })
        .then(result => {
            this.opp = result;
            this.folderId = result[OPP_PS111_FOLDER_ID_FIELD];
            if (!this.folderId) {
                return this.loadGroupOptions();
            }
            this.loading = false;
        })
        .catch(err => {
            const msg = err?.body?.message || err?.message || JSON.stringify(err);
            this.showToast('ERROR:', 'Something went wrong: ' + msg, 'error');
            this.loading = false;
        });
    }

    loadGroupOptions() {
        return getGroupOptions()
            .then(units => {
                let optionsById = {};
                for (const unit of units) {
                    let groupOption = {};
                    groupOption.label = unit.name;
                    groupOption.parentUnitId = unit.parentUnitId;
                    groupOption.value = unit.unitId;
                    groupOption.isParent = false;
                    optionsById[unit.unitId] = groupOption;
                }
                this.groupPicklistOptions = this.buildUnitOptions(optionsById);
                this.loading = false;
            })
            .catch(err => {
                this.showToast('ERROR:', `Failed to fetch groups: ${err.body?.message || err.message || err}`, 'error');
                this.loading = false;
            });
    }

    get oppName() {
        if (this.opp) {
            return this.opp[OPP_NAME_FIELD];
        }
    }

    get isCreateDisabled() {
        return this.loading || this.folderId || !this.selectedUnitId;
    }

    get processComplete() {
        return this.loading && this.folderId;
    }

    handleModalCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    /* Works by building up from the lowest level of units to the root source
     * There is a scenario that a user can have visiblity to a child folder but
     * not it's parent.*/
    buildUnitOptions(optionsById) {
        for (var optionUnitId in optionsById) {
            const option = optionsById[optionUnitId];
            const parentId = option.parentUnitId;
            if (parentId) {
                let parentOption = optionsById[parentId];
                if (parentOption) {
                    parentOption.isParent = true;
                }
            }
        };

        let childOptionsArray = [];
        for (var optionUnitId in optionsById) {
            const option = optionsById[optionUnitId];
            const parentOption = optionsById[option.parentUnitId];

            if (!option.isParent && option.parentUnitId) {
                option.label = this.buildUnitFilePath(optionsById, option, parentOption);
                childOptionsArray.push(option);
            }
        };

        return childOptionsArray.sort(this.compareOption);
    }

    compareOption(optionA, optionB) {
        if (optionA.label < optionB.label) {
            return -1;
        } else if (optionA.label > optionB.label) {
            return 1;
        } else {
            return 0;
        }
    }

    buildUnitFilePath(optionsById, childOption, parentOption) {
        let grandParentOption;
        if (parentOption && parentOption.parentUnitId) {
            grandParentOption = optionsById[parentOption.parentUnitId];
        }

        if (!childOption.isParent && parentOption) {
            return this.buildUnitFilePath(optionsById, parentOption, grandParentOption) + '/' + parentOption.label + '/' + childOption.label;
        } else if (parentOption && grandParentOption) {
            return this.buildUnitFilePath(optionsById, parentOption, grandParentOption) + '/' + parentOption.label;
        } else if (parentOption && childOption) {
            return this.buildUnitFilePath(optionsById, childOption, null) + '/' + parentOption.label;
        } else if (!childOption.isParent && !parentOption) {
            return '/' + childOption.label;
        } else {
            return '';
        }
    }

    handleChange(event) {
        this.selectedUnitId = event.detail && event.detail.value ? event.detail.value : event.detail;
    }

    handleCreate() {
        this.loading = true;
        this.loadingMessage = 'Creating folder...';

        createProposalFolder({
            unitId:      this.selectedUnitId,
            oppId:       this.opp.Id,
            oppName:     this.oppName,
            accountName: this.opp.Account.Name
        })
        .then(folderId => {
            const opportunityToUpdate = {
                fields: {
                    Id:                  this.opp.Id,
                    PS111_Folder_ID__c:  folderId
                }
            };
            return updateRecord(opportunityToUpdate);
        })
        .then(() => {
            this.showToast('Success', 'Folder has been successfully created on PS111', 'success');
            this.closeAction();
        })
        .catch(err => {
            const message = err.body?.message || err.message || JSON.stringify(err);
            this.showToast('ERROR:', 'Something went wrong creating folder in PS111: ' + message, 'error');
            this.loading = false;
        });
    }

    showToast(title, message, variant, mode = 'dismissible') {
        const toastEvent = new ShowToastEvent({
            title, message, variant, mode
        });
        this.dispatchEvent(toastEvent);
    }

    closeAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
        getRecordNotifyChange([{ recordId: this.recordId }]);
    }
}