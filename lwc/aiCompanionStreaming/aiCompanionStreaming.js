import { api, wire } from 'lwc';
import { LightningElement } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadStyle } from "lightning/platformResourceLoader";

import getAuthToken from '@salesforce/apex/OpenAiApiService.getAuthToken';
import processQuestion from '@salesforce/apex/OpenAIQuestionProcessor.processQuestion';
import getAvailableQuestionsFor from '@salesforce/apex/OpenAIQuestionProcessor.getAvailableQuestionsFor';
import actionResponseCall from '@salesforce/apex/Action.callAction';

import widerModalStyles from "@salesforce/resourceUrl/copado_devops_ai_companion_css";

import LOADING from '@salesforce/label/c.LOADING';
import CHAT_SELECT_PROMPT_LABEL from '@salesforce/label/c.CHAT_SELECT_PROMPT_LABEL';
import CHAT_SELECT_PROMPT_PLACEHOLDER from '@salesforce/label/c.CHAT_SELECT_PROMPT_PLACEHOLDER';
import CHAT_ASK_OPENAI_LABEL from '@salesforce/label/c.CHAT_ASK_OPENAI_LABEL';
import CHAT_SEND_BUTTON_LABEL from '@salesforce/label/c.CHAT_SEND_BUTTON_LABEL';
import CHAT_CLEAR_CONVERSATION_BUTTON_LABEL from '@salesforce/label/c.CHAT_CLEAR_CONVERSATION_BUTTON_LABEL';
import CHAT_OPENAI_PRIVACY_POLICY_LINK from '@salesforce/label/c.CHAT_OPENAI_PRIVACY_POLICY_LINK';
import CHAT_ASK_OPENAI_PLACEHOLDER from '@salesforce/label/c.CHAT_ASK_OPENAI_PLACEHOLDER';
import systemRoleLabel from '@salesforce/label/c.OPENAI_ROLE';
import suggestionCopied from '@salesforce/label/c.SUGGESTION_COPIED';
import labelSuccess from '@salesforce/label/c.SUCCESS';
import ERROR_BACKEND from '@salesforce/label/c.ERROR_BACKEND';
import TEXTAREA_PLACEHOLDER from '@salesforce/label/c.TEXTAREA_PLACEHOLDER';
import ACTION_DEFINITION_ERROR from '@salesforce/label/c.ACTION_DEFINITION_ERROR';
import ACTION_PLACEHOLDER from '@salesforce/label/c.ACTION_PLACEHOLDER';

import { marked } from './markdown';

export default class AiCompanionStreaming extends LightningElement {
    @api contextId;
    @api preselectedPromptName;
    @api hideFullScreen = false;

    @api max_tokens; // DEPRECATED, not in use, but could not find a way to remove it
    @api temperature; // DEPRECATED, not in use, but could not find a way to remove it
    @api engine; // DEPRECATED, not in use, but could not find a way to remove it

    userId;
    orgId;
    userName;
    backendUrl;
    backendAuthToken;
    conversationSessionId;
    namespace;

    userMessage;
    selectedQuestion;
    isLoading = true;
    more = false;
    pageReferenceCalled=false;
    initialized=false;
    selectedQuestionRec;

    availableQuestions = [];
    availableQuestionMapByLabel = {};
    hasAvailableQuestions = false;
    messages = [];
    lastMessage = {};
    statusMessage = '';

    // everything for the actions
    fuctionsClassMap = {};
    functions = [];
    functionExamples = [];

    // dynamically calculated label
    CHAT_ASK_OPENAI_LABEL_DYNAMIC =  CHAT_ASK_OPENAI_LABEL;

    labels = {
        LOADING,
        CHAT_SELECT_PROMPT_LABEL,
        CHAT_SELECT_PROMPT_PLACEHOLDER,
        CHAT_ASK_OPENAI_LABEL,
        CHAT_ASK_OPENAI_PLACEHOLDER,
        CHAT_SEND_BUTTON_LABEL,
        CHAT_CLEAR_CONVERSATION_BUTTON_LABEL,
        CHAT_OPENAI_PRIVACY_POLICY_LINK,
        ERROR_BACKEND,
        TEXTAREA_PLACEHOLDER,
        ACTION_DEFINITION_ERROR,
        ACTION_PLACEHOLDER,
    }

    @wire(CurrentPageReference) handlePageReference(pageReference) {
        // eslint-disable-next-line @lwc/lwc/no-api-reassignments
        this.contextId = pageReference.attributes?.recordId || this.extractRecordIdFromUrl();
        this.pageReferenceCalled = true;
        // only re-initialize if there is no conversation going on
        if(this.messages.length===0) {
            this.handleClear();
        }
    }

    connectedCallback() {
        try{
            this.conversationSessionId = (Math.random() + 1).toString(36);
            // trick to load an external CSS and make the modal bigger when maximized
            loadStyle(this, widerModalStyles);
        }catch(e) {
            console.warn(e);
        }
    }

    async renderedCallback() {
        try{
            this.scrollToBottom();
            this.textAreaElt = this.template.querySelector('lightning-textarea');
            if(!this.pageReferenceCalled) {
                this.pageReferenceCalled = true;
                // eslint-disable-next-line @lwc/lwc/no-api-reassignments
                this.contextId = this.extractRecordIdFromUrl(true);
                this.initializePromptsAndObject();
                if(this.hideFullScreen) {
                    // if it is not the global actions window, set the textare small
                    this.template.host.style.setProperty('--textareHeight', '0.5rem');
                }
            }
            this.rerenderMarkdownMessages();
        }catch(e) {
            console.warn('renderedCallback', e);
        }
    }

    rerenderMarkdownMessages() {
        // re-render the message(s) that were streamed
        const markdownMessages = this.template.querySelectorAll('.contentToCopy[data-content]');
        for(let elt of markdownMessages) {
            // eslint-disable-next-line @lwc/lwc/no-inner-html
            elt.innerHTML = marked()(elt.getAttribute('data-content'));
        }
    }

    async processChunkedResponse(reader) {
        let buffer = "";
        const decoder = new TextDecoder("utf-8");
        const outputElt = this.template.querySelector('.contentToCopy[data-islast="true"]');

        // eslint-disable-next-line no-constant-condition
        while (true) {
            // eslint-disable-next-line no-await-in-loop
            let { done, value } = await reader.read();
            if (done) {
                break;
            }
            let results;
            try {
                results = decoder.decode(value);
                results = results.trim().split('\n');
            } catch (e) {
                console.warn("Failed to decode", results, "Error="+e);
                continue;
            }
            for(let result of results) {
                try {
                    result = JSON.parse(result);
                } catch (e) {
                    console.warn("Failed to parse", result, "Error="+e);
                    continue;
                }
                if(result.type === 'status') {
                    this.statusMessage = result.content;
                }else if(result.type === 'error') {
                    this.statusMessage = 'Error: '+result.content;
                }else if(result.type === 'token') {
                    buffer += result.content;
                    outputElt.setAttribute('data-content', buffer);
                    // eslint-disable-next-line @lwc/lwc/no-inner-html
                    outputElt.innerHTML = marked()(buffer);
                    this.statusMessage = '';
                    this.scrollToBottom();
                }else if(result.type === 'function_call') {
                    try{
                        const fn = result.function_call;
                        console.info('AI Action requested:', fn.name, fn.arguments);
                        const args = JSON.parse(fn.arguments);
                        let className = this.fuctionsClassMap[fn.name];
                        // eslint-disable-next-line no-await-in-loop
                        let actionResult = await actionResponseCall({contextId: this.contextId, name: className, args: args});
                        // TODO: error handling? both general and specific error messages in actionResult.error
                        buffer += actionResult.message||'';
                        buffer += actionResult.error||'';
                        this.lastMessage.link = actionResult.link||'';
                        console.info('AI Action completed:', fn.name);
                    } catch (e) {
                        console.warn("Failed to execute Action", result, "Error="+e);
                        continue;
                    }
                    this.statusMessage = '';
                    this.scrollToBottom();
                }
            }
        }
        return buffer;
    }

    async authenticate() {
        this.backendAuthToken = await getAuthToken();
    }

    async sendRequest(prompt) {
        let chatGPTmessages = [{
            role: "system",
            content: "You need to assist the person asking you questions and tasks about Copado. Copado is a Salesforce Devops and Deployment tool, and most of changes in User Stories, Promotions and Deployments are related to Salesforce features and Salesforce metadata."
        }];

        // override the default assistant message
        if(this.selectedQuestionRec?.before) {
            chatGPTmessages[0].content = this.selectedQuestionRec.before;
        }
        chatGPTmessages[0].content += '\nThe reply you give should be in Markdown format.';
        chatGPTmessages = chatGPTmessages.concat(this.messages.slice(0,-1).map((m) => ({
            content: m.content,
            role: m.role,
        })));

        const body = {
            "messages": chatGPTmessages,
            "enable_tooling": false,
            "prompt": prompt,
            "functions": this.functions,
            "client_version": 'v1'
        }
        let response = {};
        try{
            this.statusMessage = '...';
            let attempts=8;
            while( attempts-- ) {
                // eslint-disable-next-line no-await-in-loop
                if(!this.backendAuthToken) { await this.authenticate(); }

                // eslint-disable-next-line no-await-in-loop
                response = await fetch(this.backendUrl, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': `Bearer ${this.backendAuthToken}`,
                        'userId': this.userId,
                        'orgId': this.orgId,
                        'sessionId': this.conversationSessionId
                    },
                    body: JSON.stringify(body),
                });
                if(response.ok) {
                    const reader = response.body.getReader();
                    // eslint-disable-next-line no-await-in-loop
                    let content = await this.processChunkedResponse(reader);
                    // save the response so we can keep the chat history
                    this.lastMessage.content = content;
                    break;
                }else if(response.status === 401) {
                    this.backendAuthToken = null;
                    continue;
                }else{
                    throw new Error(response.statusText || response.status);
                }
            }
            if(attempts<=0) {
                // could not authenticate
                throw new Error(response.statusText || response.status);
            }
        }catch(e) {
            // note: convert the e to string by concatenating. LWC proxies the object
            console.error(`${this.labels.ERROR_BACKEND} ${this.backendUrl}`, e);
            this.showErrorMessage(`${this.labels.ERROR_BACKEND} ${this.backendUrl}: ${e?.body?.message||e}`, '');
            this.messages.pop();
            console.warn('The body of the request was:', JSON.stringify(body, null, 4));
        }finally{
            this.isLoading = false;
            this.lastMessage.islast = false;
            this.rerenderMarkdownMessages();
        }
    }

    async handleSubmit() {
        if(!this.userMessage) {
            return
        }
        try {
            const msg = this.userMessage
            this.addMessage(msg, true, false);

            this.template.host.style.setProperty('--textareHeight', '0.5rem');
            this.userMessage = '';
            this.isLoading = true;
            this.scrollToBottom();

            this.textAreaElt.value = '';
            this.textAreaElt.placeholder = this.labels.TEXTAREA_PLACEHOLDER;

            // add a bubble, where the message will be written
            this.addMessage('', false, false);
            this.lastMessage = this.messages[this.messages.length-1];
            this.lastMessage.islast = true;

            // detach the request so the UI can rerender
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            window.setTimeout( async () => { await this.sendRequest(msg) }, 10);
        } catch(err) {
            this.showErrorMessage(err, '');
        } finally {
            this.scrollToBottom();
        }
    }

    initializePromptsAndObject() {
        getAvailableQuestionsFor({ contextId: this.contextId })
        .then((result) => {
            this.isLoading = false;
            console.debug('initializePromptsAndObject', this.contextId, result);
            this.CHAT_ASK_OPENAI_LABEL_DYNAMIC = this.labels.CHAT_ASK_OPENAI_LABEL + ' ' + result.objectLabel;
            this.availableQuestions = result.prompts.map(x => ({name: x.name, label: x.label, value: x.label}));
            this.availableQuestionMapByLabel = Object.fromEntries(result.prompts.map(x => [x.label, x]));
            this.hasAvailableQuestions = this.availableQuestions.length > 0;
            this.backendUrl = result.backendUrl;
            this.userId = result.userId;
            this.orgId = result.orgId;
            this.userName = result.userName;
            this.namespace = result.namespace;
            this.selectedQuestion = this.preselectedPromptName;

            // NOTE: if it is not english/us we concatenate the language code of this user
            // so they can troubleshoot why and who sees which Prompts
            const lang = result.languageLocaleKey?.replace(/_.*/, '');
            if(lang !== 'en') {
                this.userName += ` (${lang})`;
            }

            this.fuctionsClassMap = {};
            this.functions = [];
            this.functionExamples = [];
            if(result.actions && Object.keys(result.actions).length) {
                for(let [className, schema] of Object.entries(result.actions)) {
                    try{
                        schema = JSON.parse(schema);
                    }catch(e) {
                        console.warn(schema);
                        throw new Error(this.labels.ACTION_DEFINITION_ERROR+' '+className+': '+e);
                    }
                    this.functionExamples = this.functionExamples.concat( schema.examples.map(x => ({label: x, value: x})) );
                    delete schema.examples; // need to remove it... it is not part of OpenaI
                    this.functions.push(schema);
                    this.fuctionsClassMap[schema.name] = className
                }
            }
        })
        .catch((err) => {
            this.showErrorMessage(err, '');
            this.hasAvailableQuestions = this.availableQuestions.length > 0;
        });
    }

    scrollToBottom() {
        const scrollArea = this.template.querySelector('lightning-textarea');
        scrollArea.scrollIntoView({ block: "end" });
        //scrollArea.scrollTop = scrollArea.scrollHeight;
        //scrollArea.scrollIntoView();
    }

    get hasMessages() {
        return this.messages.length > 0;
    }

    handleUserMesssage(event){
        this.userMessage = event.target.value;
    }

    handleClear() {
        this.selectedQuestion = undefined;
        this.selectedQuestionRec = undefined;
        this.userMessage = '';
        this.statusMessage = '';
        this.messages = [];
        const textArea = this.template.querySelector("lightning-textarea");
        if(textArea) {
            textArea.value = "";
            textArea.placeholder = this.labels.CHAT_ASK_OPENAI_PLACEHOLDER;
        }
        // re-read the context id, in case the user navigated to another record
        this.initializePromptsAndObject();
        if(!this.hideFullScreen) {
            // if it is the global actions window, set the textare big
            this.template.host.style.setProperty('--textareHeight', '');
        }
    }

    async handleSelectQuestion(event) {
        this.selectedQuestion = event.detail.value;
        this.selectedQuestionRec = this.availableQuestionMapByLabel[this.selectedQuestion];

        processQuestion({
            contextId: this.contextId,
            questionRec: this.selectedQuestionRec
        }).then((result) => {
            console.debug('processQuestion', result);
            this.selectedQuestionRec = result;
            this.userMessage = result.prompt;
            const textArea = this.template.querySelector('lightning-textarea');
            textArea.value = result.prompt;
            textArea.focus();
        }).catch((err) => {
            this.showErrorMessage(err, 'There was an error(1)');
            this.isLoading=false;
        });
    }

    handleAction(event) {
        // simulate typing
        this.userMessage = event.target.value;
        this.handleSubmit(new CustomEvent('click'));
        this.userMessage = '';
        event.target.value = '';
    }

    addMessage(content, fromUser, more) {
        this.messages.push({
            timestamp: this.messages.length,
            content: '' + content,
            role: fromUser ? 'user' : 'assistant',
            sender: fromUser ?this.userName :systemRoleLabel,
            isAssistant: !fromUser,
            more,
        });
    }

    showErrorMessage(err) {
        console.error(err);
        let userError = err.body
            ? (err.body.message ? `${err?.body?.message}\n${err.body.exceptionType||''}\n${err.body.stackTrace||''}` : err.body)
            : '' + err;
        this.statusMessage = `${userError}`;
        const event = new ShowToastEvent({
            title: 'There was an error',
            message: userError,
            variant: 'error'
        });
        this.dispatchEvent(event);
    }

    showNotification(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    handleCopy(event) {
        try{
            const contentToCopyElt = event.target.closest(".bubble").querySelector(".contentToCopy");
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
                if(document.execCommand('copy')) res(); else rej();
                textArea.remove();
                this.showNotification(labelSuccess, suggestionCopied, 'success');
            });
        }catch(e) {
            console.error(e, ''+e);
        }
        return null;
    }

    handleOpenTab() {
        const NS = this.namespace ? `${this.namespace}/` : '';
        const url = `/flow/${NS}Copado_DevOps_AI_Companion?recordId=${this.contextId}&j=${encodeURIComponent(JSON.stringify(this.messages))}`;
        window.open(url, "_blank");
    }

    extractRecordIdFromUrl(isCalledFromRenderedCallback) {
        let recordId = null;
        try{
            // complex way to parse several url types and extract a relevant ID
            // only used in Deployment and similar Pages
            let t = window.location.href;
            let m = /\/one\/one.app#(.*)/i.exec(t);
            if(m) {
                try{
                    t = m[1];
                    t = decodeURIComponent(t);
                    t = atob(t);
                    t = JSON.parse(t);
                    t = t.attributes.address;
                }catch(e) {
                    console.error('Error while decoding one.app urls', e, t);
                }
            }
            m = /[a-z0-9_]+__c\/([a-z0-9]{18})/i.exec(t);
            if(m) {
                recordId = m[1];
            }else{
                m = /[?&](?:record)?id=([a-z0-9]{15,18})/i.exec(t);
                if(m) {
                    recordId = m[1];
                }
            }
            if(isCalledFromRenderedCallback) {
                let params = (new URL(document.location)).searchParams;
                if(params.get("j")) {
                    // eslint-disable-next-line @lwc/lwc/no-api-reassignments
                    this.hideFullScreen = true;
                    this.messages = JSON.parse(params.get("j"));
                }
            }
            console.debug('extractRecordIdFromUrl', t, recordId);
        }catch(e) {
            console.error(e);
        }
        return recordId;
    }
}