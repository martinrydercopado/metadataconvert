import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export const reduceErrors = (errors) => {
    if (!Array.isArray(errors)) {
        errors = [errors];
    }

    return (
        errors
            .filter((error) => !!error)
            .map((error) => {
                // UI API read errors
                if (Array.isArray(error.body)) {
                    return error.body.map((e) => e.message);
                }
                // UI API DML, Apex and network errors
                else if (error.body && typeof error.body.message === 'string') {
                    return error.body.message;
                }
                // JS errors
                else if (typeof error.message === 'string') {
                    return error.message;
                }
                // Unknown error shape so try HTTP status text
                return error.statusText;
            })
            .reduce((prev, curr) => prev.concat(curr), [])
            .filter((message) => !!message)
            .join()
    );
};

export const showToastError = (self, options) => {
    options = options ? options : {};

    const showError = new ShowToastEvent({
        variant: 'error',
        title: options.title || 'Error',
        message: options.message || '',
        messageData: options.messageData || [],
        mode: options.mode || 'dismissable'
    });
    self.dispatchEvent(showError);
};

export const showToastWarning = (self, options) => {
    options = options ? options : {};

    const showWarn = new ShowToastEvent({
        variant: 'warning',
        title: options.title || 'Warning',
        message: options.message || '',
        mode: options.mode || 'dismissable'
    });
    self.dispatchEvent(showWarn);
};