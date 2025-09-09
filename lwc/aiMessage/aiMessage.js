import { LightningElement, api } from 'lwc';
import systemRoleLabel from '@salesforce/label/c.OPENAI_ROLE';
import suggestionCopied from '@salesforce/label/c.SUGGESTION_COPIED';
import labelSuccess from '@salesforce/label/c.SUCCESS';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import { marked } from './markdown';

export default class AiMessage extends LightningElement {
    @api role;
    @api timestamp;
    @api content;
    @api link;
    @api username;
    @api more;

    get sender() {
        return this.role === 'user' ? this.username : systemRoleLabel;
    }

    get bubbleClass() {
        return `bubble ${this.role}`;
    }

    get copy() {
        return this.role !== 'user';
    }

    renderedCallback() {
        // re-enable the show-more button if it was disabled when clicking it
        // and re-render the contents (it might have additional information)
        let t = this.template.querySelector('.show-more');
        if(t) { t.disabled=false; }

        if(this.role !== 'user') {
            // eslint-disable-next-line @lwc/lwc/no-inner-html
            this.template.querySelector('pre').innerHTML = marked()(this.content);
        }else{
            this.template.querySelector('pre').innerText = this.content;
        }
    }

    handleContinue(event) {
        this.dispatchEvent(new CustomEvent('openaicontinue', { bubbles: true, composed: false }));
        event.target.disabled=true;
    }

    handleCopy() {
        const contentToCopyElt = this.template.querySelector("pre:last-of-type");
        const text = contentToCopyElt.innerText;

        if (navigator.clipboard && window.isSecureContext) {
            this.showNotification(labelSuccess, suggestionCopied, 'success');
            return navigator.clipboard.writeText(text);
        }

        let textArea = document.createElement('textarea');
        textArea.value = text;
        textArea.style.position = 'fixed';
        textArea.style.left = '-999999px';
        textArea.style.top = '-999999px';
        document.body.appendChild(textArea);
        textArea.focus();
        textArea.select();

        return new Promise((res, rej) => {
            document.execCommand('copy') ? res() : rej();
            textArea.remove();
            this.showNotification(labelSuccess, suggestionCopied, 'success');
        });
    }

    showNotification(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}