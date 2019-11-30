import { LightningElement, track, api } from 'lwc';

export default class Selector extends LightningElement {
    @track selectedProductId;

    handleProductSelected(evt) {
        this.selectedProductId = evt.detail;
    }
}
