import structlog

from openconnect_sso.browser import Browser

log = structlog.get_logger()


async def authenticate_in_browser(auth_info, credentials):
    async with Browser() as browser:
        await browser.authenticate_at(auth_info.login_url, credentials)

        while browser.url != auth_info.login_final_url:
            await browser.page_loaded()
            log.debug("Browser loaded page", url=browser.url)

    return browser.cookies[auth_info.token_cookie_name]
