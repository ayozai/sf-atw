import { LightningElement, api } from 'lwc';

export default class CustomCombobox extends LightningElement {

    @api placeholder = 'Select an Option';
    @api label;
    @api options = [];

    handleChange(event)
    {
        event.preventDefault();

        console.log('here', event.target.value);
        this.dispatchEvent(new CustomEvent('change', { detail: event.target.value }));
    }
}