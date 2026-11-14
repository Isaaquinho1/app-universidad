-- Conecta ITT
-- Restrict administrative photograph review RPCs.

begin;

revoke execute
on function public.get_unseen_profile_photo_review_count()
from public, anon;

revoke execute
on function public.mark_profile_photo_reviews_seen()
from public, anon;

grant execute
on function public.get_unseen_profile_photo_review_count()
to authenticated;

grant execute
on function public.mark_profile_photo_reviews_seen()
to authenticated;

commit;
