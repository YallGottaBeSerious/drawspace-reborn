import { createClient } from '@supabase/supabase-js';

const url = 'https://rnttiwnbagdjduxpotvi.supabase.co';
const key = 'PASTE_YOUR_ANON_PUBLIC_KEY_HERE';
export const configured = Boolean(url && key && !url.includes('YOUR_PROJECT'));
export const supabase = configured ? createClient(url, key) : null;
