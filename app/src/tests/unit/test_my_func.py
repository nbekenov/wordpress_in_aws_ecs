import pytest
from app import my_func


def test_add():
    assert my_func.add(4, 5) == 9


def test_subtract():
    assert my_func.subtract(4, 5) == -1


def test_multiply():
    assert my_func.multiply(4, 5) == 20


def test_multiply2():
    assert my_func.multiply(4, 10) == 40