import { createClient } from '@supabase/supabase-js';

const url = 'https://rnttiwnbagdjduxpotvi.supabase.co';
const key = 'sb_publishable_XwM6-4BqcT9nha4MbTJCeA_uMbCLH8r';
export const configured = Boolean(url && key && !url.includes('YOUR_PROJECT'));
export const supabase = configured ? createClient(url, key) : null;
