import { writable, derived } from 'svelte/store';
import en from './locales/en.json';
import pt from './locales/pt.json';

const messages = { en, pt };

const detected = typeof navigator !== 'undefined' && navigator.language.startsWith('pt') ? 'pt' : 'en';

export const locale = writable(detected);

export const t = derived(locale, $locale => key => messages[$locale]?.[key] ?? key);
