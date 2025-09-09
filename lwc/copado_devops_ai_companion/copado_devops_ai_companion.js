import { api } from 'lwc';
import { LightningElement } from 'lwc';
export default class Copado_devops_ai_companion extends LightningElement {
    @api contextId;
    @api max_tokens;
    @api temperature;
    @api engine;
}